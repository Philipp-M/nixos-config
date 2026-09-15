use regex::{Regex, RegexBuilder};
use serde::Deserialize;
use serde_json::{Value, json};
use std::{
    cmp::Ordering,
    collections::{BTreeMap, BTreeSet, HashSet},
    env,
    ffi::{CStr, CString, c_char, c_int, c_uint, c_ulong},
    fs,
    io::{self, BufRead, BufReader, Read, Write},
    net::{TcpListener, TcpStream},
    os::unix::net::UnixStream,
    path::{Path, PathBuf},
    process::{Child, ChildStdin, Command, Stdio},
    sync::{Arc, Mutex},
    thread,
    time::Instant,
};

type Error = Box<dyn std::error::Error + Send + Sync>;
type Result<T> = std::result::Result<T, Error>;

const PROXY_LISTEN: &str = "127.0.0.1:2814";
const LLAMA_ADDR: &str = "127.0.0.1:2813";

const SND_SEQ_OPEN_INPUT: c_int = 2;
const SND_SEQ_PORT_CAP_WRITE: c_uint = 1 << 1;
const SND_SEQ_PORT_CAP_SUBS_WRITE: c_uint = 1 << 6;
const SND_SEQ_PORT_TYPE_MIDI_GENERIC: c_uint = 1 << 1;
const SND_SEQ_PORT_TYPE_APPLICATION: c_uint = 1 << 20;
const SND_SEQ_EVENT_NOTEON: u8 = 6;
const SND_SEQ_EVENT_NOTEOFF: u8 = 7;

#[repr(C)]
struct SndSeq {
    private: [u8; 0],
}

#[repr(C)]
struct SndSeqPortSubscribe {
    private: [u8; 0],
}

#[repr(C)]
#[derive(Clone, Copy)]
struct SndSeqAddr {
    client: u8,
    port: u8,
}

#[repr(C)]
#[derive(Clone, Copy)]
union SndSeqTimestamp {
    tick: u32,
    time: [u32; 2],
}

#[repr(C)]
#[derive(Clone, Copy)]
struct SndSeqNote {
    channel: u8,
    note: u8,
    velocity: u8,
    off_velocity: u8,
    duration: u32,
}

#[repr(C)]
#[derive(Clone, Copy)]
union SndSeqEventData {
    note: SndSeqNote,
    alignment_and_size: [u64; 2],
}

#[repr(C)]
struct SndSeqEvent {
    event_type: u8,
    flags: u8,
    tag: u8,
    queue: u8,
    time: SndSeqTimestamp,
    source: SndSeqAddr,
    dest: SndSeqAddr,
    data: SndSeqEventData,
}

#[link(name = "asound")]
unsafe extern "C" {
    fn snd_seq_open(
        handle: *mut *mut SndSeq,
        name: *const c_char,
        streams: c_int,
        mode: c_int,
    ) -> c_int;
    fn snd_seq_close(handle: *mut SndSeq) -> c_int;
    fn snd_seq_set_client_name(handle: *mut SndSeq, name: *const c_char) -> c_int;
    fn snd_seq_client_id(handle: *mut SndSeq) -> c_int;
    fn snd_seq_create_simple_port(
        handle: *mut SndSeq,
        name: *const c_char,
        caps: c_uint,
        port_type: c_uint,
    ) -> c_int;
    fn snd_seq_parse_address(
        handle: *mut SndSeq,
        addr: *mut SndSeqAddr,
        text: *const c_char,
    ) -> c_int;
    fn snd_seq_port_subscribe_malloc(info: *mut *mut SndSeqPortSubscribe) -> c_int;
    fn snd_seq_port_subscribe_free(info: *mut SndSeqPortSubscribe);
    fn snd_seq_port_subscribe_set_sender(info: *mut SndSeqPortSubscribe, addr: *const SndSeqAddr);
    fn snd_seq_port_subscribe_set_dest(info: *mut SndSeqPortSubscribe, addr: *const SndSeqAddr);
    fn snd_seq_port_subscribe_set_exclusive(info: *mut SndSeqPortSubscribe, value: c_int);
    fn snd_seq_subscribe_port(handle: *mut SndSeq, info: *mut SndSeqPortSubscribe) -> c_int;
    fn snd_seq_event_input(handle: *mut SndSeq, event: *mut *mut SndSeqEvent) -> c_int;
    fn snd_strerror(error: c_int) -> *const c_char;
}

#[derive(Debug, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
struct MatchConfig {
    overview: Option<bool>,
    process: Option<String>,
    app_id: Option<String>,
    layer_namespace: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct LlmModeConfig {
    name: String,
    priority: i64,
    #[serde(rename = "match", default)]
    matcher: MatchConfig,
    context: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct TransformConfig {
    name: String,
    pattern: String,
    replace: String,
    #[serde(default)]
    lowercase: bool,
    #[serde(default)]
    lowercase_first: bool,
    #[serde(default)]
    trim_end_punctuation: bool,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct TransformModeConfig {
    name: String,
    priority: i64,
    #[serde(rename = "match", default)]
    matcher: MatchConfig,
    #[serde(default)]
    transforms: Vec<TransformConfig>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct CommandModeConfig {
    name: String,
    priority: i64,
    #[serde(rename = "match", default)]
    matcher: MatchConfig,
    #[serde(default)]
    commands: BTreeMap<String, String>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct RuntimeConfigFile {
    #[serde(default = "default_true")]
    llm_enabled: bool,
    llm_default: String,
    #[serde(default)]
    llm_modes: Vec<LlmModeConfig>,
    #[serde(default)]
    dictation_transforms: Vec<TransformConfig>,
    #[serde(default)]
    dictation_modes: Vec<TransformModeConfig>,
    #[serde(default = "default_submit_delay_ms")]
    submit_delay_ms: u64,
    #[serde(default)]
    command_default: BTreeMap<String, String>,
    #[serde(default)]
    command_modes: Vec<CommandModeConfig>,
}

struct Matcher {
    overview: Option<bool>,
    process: Option<Regex>,
    app_id: Option<Regex>,
    layer_namespace: Option<Regex>,
}

impl Matcher {
    fn compile(raw: MatchConfig) -> Result<Self> {
        Ok(Self {
            overview: raw.overview,
            process: compile_regex(raw.process, false)?,
            app_id: compile_regex(raw.app_id, true)?,
            layer_namespace: compile_regex(raw.layer_namespace, true)?,
        })
    }

    fn matches(&self, snapshot: &Snapshot) -> bool {
        if let Some(expected) = self.overview {
            if snapshot.overview != expected {
                return false;
            }
        }

        if let Some(regex) = &self.app_id {
            let Some(app_id) = snapshot.focused.app_id.as_deref() else {
                return false;
            };
            if !regex.is_match(app_id) {
                return false;
            }
        }

        if let Some(regex) = &self.layer_namespace {
            if !snapshot
                .interactive_layer_names
                .iter()
                .any(|name| regex.is_match(name))
            {
                return false;
            }
        }

        if let Some(regex) = &self.process {
            if !snapshot
                .processes
                .iter()
                .any(|process| process.foreground && regex.is_match(&process.name))
            {
                return false;
            }
        }

        true
    }
}

fn compile_regex(pattern: Option<String>, case_insensitive: bool) -> Result<Option<Regex>> {
    match pattern {
        Some(pattern) => Ok(Some(
            RegexBuilder::new(&pattern)
                .case_insensitive(case_insensitive)
                .build()?,
        )),
        None => Ok(None),
    }
}

struct LlmMode {
    name: String,
    priority: i64,
    matcher: Matcher,
    context: String,
}

struct TransformMode {
    name: String,
    priority: i64,
    matcher: Matcher,
    transforms: Vec<Transform>,
}

struct Transform {
    name: String,
    pattern: Regex,
    replace: String,
    lowercase: bool,
    lowercase_first: bool,
    trim_end_punctuation: bool,
}

struct CommandMode {
    name: String,
    priority: i64,
    matcher: Matcher,
    commands: BTreeMap<String, String>,
}

struct RuntimeConfig {
    llm_enabled: bool,
    llm_default: String,
    llm_modes: Vec<LlmMode>,
    dictation_transforms: Vec<Transform>,
    dictation_modes: Vec<TransformMode>,
    submit_delay_ms: u64,
    command_default: BTreeMap<String, String>,
    command_modes: Vec<CommandMode>,
}

impl RuntimeConfig {
    fn load(path: &Path) -> Result<Self> {
        let raw: RuntimeConfigFile = serde_json::from_slice(&fs::read(path)?)?;

        let mut llm_modes = raw
            .llm_modes
            .into_iter()
            .map(|mode| {
                Ok(LlmMode {
                    name: mode.name,
                    priority: mode.priority,
                    matcher: Matcher::compile(mode.matcher)?,
                    context: mode.context,
                })
            })
            .collect::<Result<Vec<_>>>()?;
        llm_modes.sort_by(|a, b| b.priority.cmp(&a.priority));

        let dictation_transforms = raw
            .dictation_transforms
            .into_iter()
            .map(Transform::compile)
            .collect::<Result<Vec<_>>>()?;

        let mut dictation_modes = raw
            .dictation_modes
            .into_iter()
            .map(|mode| {
                Ok(TransformMode {
                    name: mode.name,
                    priority: mode.priority,
                    matcher: Matcher::compile(mode.matcher)?,
                    transforms: mode
                        .transforms
                        .into_iter()
                        .map(Transform::compile)
                        .collect::<Result<Vec<_>>>()?,
                })
            })
            .collect::<Result<Vec<_>>>()?;
        dictation_modes.sort_by(|a, b| b.priority.cmp(&a.priority));

        let mut command_modes = raw
            .command_modes
            .into_iter()
            .map(|mode| {
                Ok(CommandMode {
                    name: mode.name,
                    priority: mode.priority,
                    matcher: Matcher::compile(mode.matcher)?,
                    commands: mode.commands,
                })
            })
            .collect::<Result<Vec<_>>>()?;
        command_modes.sort_by(|a, b| b.priority.cmp(&a.priority));

        Ok(Self {
            llm_enabled: raw.llm_enabled,
            llm_default: raw.llm_default,
            llm_modes,
            dictation_transforms,
            dictation_modes,
            submit_delay_ms: raw.submit_delay_ms,
            command_default: raw.command_default,
            command_modes,
        })
    }
}

fn default_submit_delay_ms() -> u64 {
    500
}

fn default_true() -> bool {
    true
}

impl Transform {
    fn compile(raw: TransformConfig) -> Result<Self> {
        Ok(Self {
            name: raw.name,
            pattern: Regex::new(&raw.pattern)?,
            replace: raw.replace,
            lowercase: raw.lowercase,
            lowercase_first: raw.lowercase_first,
            trim_end_punctuation: raw.trim_end_punctuation,
        })
    }

    fn apply(&self, input: &str) -> Option<String> {
        if !self.pattern.is_match(input) {
            return None;
        }

        let mut output = self
            .pattern
            .replace_all(input, self.replace.as_str())
            .into_owned();
        if self.trim_end_punctuation {
            output.truncate(
                output
                    .trim_end_matches(|character| matches!(character, '.' | '?' | '!'))
                    .len(),
            );
        }
        if self.lowercase {
            return Some(output.to_lowercase());
        }
        if self.lowercase_first {
            if let Some((index, first)) =
                output.char_indices().find(|(_, char)| char.is_alphabetic())
            {
                let mut normalized = String::with_capacity(output.len());
                normalized.push_str(&output[..index]);
                normalized.extend(first.to_lowercase());
                normalized.push_str(&output[index + first.len_utf8()..]);
                return Some(normalized);
            }
        }
        Some(output)
    }
}

struct FocusedWindow {
    raw: Value,
    app_id: Option<String>,
    title: Option<String>,
    pid: Option<u32>,
}

struct ProcessInfo {
    name: String,
    foreground: bool,
}

struct Snapshot {
    focused: FocusedWindow,
    interactive_layers: Vec<Value>,
    interactive_layer_names: Vec<String>,
    overview: bool,
    processes: Vec<ProcessInfo>,
}

impl Snapshot {
    fn capture() -> Result<Self> {
        let focused_response = niri_request(json!("FocusedWindow"))?;
        let focused_raw = focused_response
            .get("FocusedWindow")
            .cloned()
            .unwrap_or(Value::Null);

        let focused = if focused_raw.is_null() {
            FocusedWindow {
                raw: Value::Null,
                app_id: None,
                title: None,
                pid: None,
            }
        } else {
            FocusedWindow {
                app_id: focused_raw
                    .get("app_id")
                    .and_then(Value::as_str)
                    .map(str::to_owned),
                title: focused_raw
                    .get("title")
                    .and_then(Value::as_str)
                    .map(str::to_owned),
                pid: focused_raw
                    .get("pid")
                    .and_then(Value::as_u64)
                    .and_then(|pid| u32::try_from(pid).ok()),
                raw: focused_raw,
            }
        };

        let layers_response = niri_request(json!("Layers"))?;
        let mut interactive_layers = Vec::new();
        let mut interactive_layer_names = Vec::new();

        if let Some(layers) = layers_response.get("Layers").and_then(Value::as_array) {
            for layer in layers {
                if !layer_is_interactive(layer) {
                    continue;
                }

                if let Some(namespace) = layer.get("namespace").and_then(Value::as_str) {
                    interactive_layer_names.push(namespace.to_owned());
                }

                interactive_layers.push(layer.clone());
            }
        }

        let overview_response = niri_request(json!("OverviewState"))?;
        let overview = overview_response
            .get("OverviewState")
            .and_then(|value| value.get("is_open"))
            .and_then(Value::as_bool)
            .unwrap_or(false);

        let mut processes = Vec::new();
        if let Some(pid) = focused.pid {
            let mut visited = HashSet::new();
            collect_process_tree(pid, &mut visited, &mut processes);
        }

        Ok(Self {
            focused,
            interactive_layers,
            interactive_layer_names,
            overview,
            processes,
        })
    }
}

fn layer_is_interactive(layer: &Value) -> bool {
    match layer.get("keyboard_interactivity") {
        Some(Value::String(value)) => value != "None",
        Some(Value::Null) | None => false,
        Some(_) => true,
    }
}

fn niri_request(request: Value) -> Result<Value> {
    let socket =
        env::var_os("NIRI_SOCKET").ok_or_else(|| io::Error::other("NIRI_SOCKET is not set"))?;

    let mut stream = UnixStream::connect(socket)?;
    serde_json::to_writer(&mut stream, &request)?;
    stream.write_all(b"\n")?;
    stream.flush()?;

    let mut reply = String::new();
    BufReader::new(stream).read_line(&mut reply)?;

    if reply.is_empty() {
        return Err(io::Error::other("empty niri IPC response").into());
    }

    let reply: Value = serde_json::from_str(&reply)?;
    match reply.get("Ok") {
        Some(value) => Ok(value.clone()),
        None => Err(io::Error::other(format!("niri IPC error: {reply}")).into()),
    }
}

fn normalize_process_name(name: &str) -> String {
    let name = name.trim();
    if name.starts_with('.') && name.ends_with("-wrapped") && name.len() > 9 {
        name[1..name.len() - "-wrapped".len()].to_owned()
    } else {
        name.to_owned()
    }
}

fn collect_process_tree(pid: u32, visited: &mut HashSet<u32>, out: &mut Vec<ProcessInfo>) {
    if !visited.insert(pid) {
        return;
    }

    if let Ok(comm) = fs::read_to_string(format!("/proc/{pid}/comm")) {
        out.push(ProcessInfo {
            name: normalize_process_name(&comm),
            foreground: process_is_foreground(pid),
        });
    }

    let Ok(tasks) = fs::read_dir(format!("/proc/{pid}/task")) else {
        return;
    };

    let mut children = BTreeSet::new();
    for task in tasks.flatten() {
        let children_path = task.path().join("children");
        let Ok(task_children) = fs::read_to_string(children_path) else {
            continue;
        };

        for child in task_children.split_whitespace() {
            if let Ok(child) = child.parse::<u32>() {
                children.insert(child);
            }
        }
    }

    for child in children {
        collect_process_tree(child, visited, out);
    }
}

fn process_is_foreground(pid: u32) -> bool {
    let Ok(stat) = fs::read_to_string(format!("/proc/{pid}/stat")) else {
        return false;
    };
    let Some((_, rest)) = stat.rsplit_once(") ") else {
        return false;
    };
    let fields: Vec<&str> = rest.split_whitespace().collect();
    let Some(pgrp) = fields.get(2).and_then(|value| value.parse::<i64>().ok()) else {
        return false;
    };
    let Some(tpgid) = fields.get(5).and_then(|value| value.parse::<i64>().ok()) else {
        return false;
    };
    tpgid > 0 && pgrp == tpgid
}

fn context_for(config: &RuntimeConfig, snapshot: &Snapshot) -> String {
    let focused = if snapshot.focused.raw.is_null() {
        Value::Null
    } else {
        json!({
            "app_id": snapshot.focused.app_id,
            "title": snapshot.focused.title,
            "pid": snapshot.focused.pid,
        })
    };

    let layers = Value::Array(
        snapshot
            .interactive_layers
            .iter()
            .map(|layer| {
                json!({
                    "namespace": layer.get("namespace").cloned().unwrap_or(Value::Null),
                    "layer": layer.get("layer").cloned().unwrap_or(Value::Null),
                    "keyboard_interactivity": layer
                        .get("keyboard_interactivity")
                        .cloned()
                        .unwrap_or(Value::Null),
                })
            })
            .collect(),
    );

    let process_names = snapshot
        .processes
        .iter()
        .map(|process| process.name.as_str())
        .collect::<BTreeSet<_>>()
        .into_iter()
        .collect::<Vec<_>>()
        .join(",");

    let mut context = format!(
        "{}\n\nDesktop context:\nfocused_window: {}\ninteractive_layers: {}\nprocesses: [{}]\noverview: {}",
        config.llm_default, focused, layers, process_names, snapshot.overview,
    );

    if let Some(mode) = active_llm_mode(config, snapshot) {
        context.push_str(&format!("\n\nContext {}:\n{}", mode.name, mode.context));
    }

    context
}

fn active_llm_mode<'a>(config: &'a RuntimeConfig, snapshot: &Snapshot) -> Option<&'a LlmMode> {
    config
        .llm_modes
        .iter()
        .find(|mode| mode.matcher.matches(snapshot))
}

fn active_transform_mode<'a>(
    config: &'a RuntimeConfig,
    snapshot: &Snapshot,
) -> Option<&'a TransformMode> {
    config
        .dictation_modes
        .iter()
        .find(|mode| mode.matcher.matches(snapshot))
}

struct TransformMatch {
    rule: String,
    output: String,
    actions_before: Vec<TransformAction>,
    submit: bool,
}

#[derive(Debug, PartialEq, Eq)]
enum TransformAction {
    Key(String),
    Wait(u64),
}

fn replacement_actions(mut output: String) -> TransformMatchActions {
    let mut actions_before = Vec::new();

    loop {
        if let Some(rest) = output.strip_prefix(r"\k{") {
            let Some(end) = rest.find('}') else {
                break;
            };
            actions_before.push(TransformAction::Key(rest[..end].to_owned()));
            output = rest[end + 1..].to_owned();
            continue;
        }

        if let Some(rest) = output.strip_prefix(r"\w{") {
            let Some(end) = rest.find('}') else {
                break;
            };
            let Ok(milliseconds) = rest[..end].parse::<u64>() else {
                break;
            };
            actions_before.push(TransformAction::Wait(milliseconds));
            output = rest[end + 1..].to_owned();
            continue;
        }

        break;
    }

    let submit = output.ends_with('\n');
    if submit {
        output.truncate(output.trim_end_matches('\n').len());
    }

    TransformMatchActions {
        output,
        actions_before,
        submit,
    }
}

struct TransformMatchActions {
    output: String,
    actions_before: Vec<TransformAction>,
    submit: bool,
}

fn selected_text(body: &[u8]) -> Result<Option<String>> {
    let request: Value = serde_json::from_slice(body)?;
    let Some(messages) = request.get("messages").and_then(Value::as_array) else {
        return Ok(None);
    };

    let Some(content) = messages.iter().rev().find_map(|message| {
        (message.get("role").and_then(Value::as_str) == Some("user"))
            .then(|| message.get("content").and_then(Value::as_str))
            .flatten()
    }) else {
        return Ok(None);
    };

    let Some(content) = content.strip_prefix("Selected text:\n") else {
        return Ok(None);
    };
    let Some((text, _)) = content.rsplit_once("\n\nInstruction:") else {
        return Ok(None);
    };

    Ok(Some(text.to_owned()))
}

fn apply_transform(
    config: &RuntimeConfig,
    snapshot: &Snapshot,
    body: &[u8],
) -> Result<Option<TransformMatch>> {
    let Some(input) = selected_text(body)? else {
        return Ok(None);
    };

    let mut output = input;
    let mut matched_rules = Vec::new();
    for transform in &config.dictation_transforms {
        if let Some(transformed) = transform.apply(&output) {
            output = transformed;
            matched_rules.push(transform.name.clone());
        }
    }

    if let Some(mode) = active_transform_mode(config, snapshot) {
        for transform in &mode.transforms {
            if let Some(transformed) = transform.apply(&output) {
                output = transformed;
                matched_rules.push(format!("{}.{}", mode.name, transform.name));
            }
        }
    }

    if matched_rules.is_empty() {
        return Ok(None);
    }

    let actions = replacement_actions(output);
    Ok(Some(TransformMatch {
        rule: matched_rules.join(" -> "),
        output: actions.output,
        actions_before: actions.actions_before,
        submit: actions.submit,
    }))
}

fn transformed_response(stream: &mut TcpStream, content: &str) -> Result<()> {
    let body = serde_json::to_vec(&json!({
        "choices": [{
            "message": {
                "role": "assistant",
                "content": content,
            }
        }]
    }))?;

    eprintln!("--- WHISRS OUTPUT ---");
    eprintln!("{content}");

    write!(
        stream,
        concat!(
            "HTTP/1.1 200 OK\r\n",
            "Content-Type: application/json\r\n",
            "Content-Length: {}\r\n",
            "Connection: close\r\n",
            "\r\n"
        ),
        body.len(),
    )?;
    stream.write_all(&body)?;
    stream.flush()?;
    Ok(())
}

fn inject_context(body: &[u8], context: &str) -> Result<Vec<u8>> {
    let mut request: Value = serde_json::from_slice(body)?;
    let object = request
        .as_object_mut()
        .ok_or_else(|| io::Error::other("request JSON is not an object"))?;

    let messages_value = object
        .entry("messages")
        .or_insert_with(|| Value::Array(Vec::new()));
    let old_messages = messages_value.take();
    let messages = old_messages
        .as_array()
        .ok_or_else(|| io::Error::other("messages is not an array"))?;

    let mut system_parts = Vec::new();
    let mut non_system = Vec::new();

    for message in messages.iter().cloned() {
        let is_system = message
            .get("role")
            .and_then(Value::as_str)
            .is_some_and(|role| role == "system");

        if is_system {
            if let Some(content) = message.get("content") {
                match content {
                    Value::String(content) => system_parts.push(content.clone()),
                    other => system_parts.push(other.to_string()),
                }
            }
        } else {
            non_system.push(message);
        }
    }

    system_parts.push(context.to_owned());

    let mut merged = Vec::with_capacity(non_system.len() + 1);
    merged.push(json!({
        "role": "system",
        "content": system_parts.join("\n\n"),
    }));
    merged.extend(non_system);

    *messages_value = Value::Array(merged);
    Ok(serde_json::to_vec(&request)?)
}

fn find_header_end(data: &[u8]) -> Option<usize> {
    data.windows(4)
        .position(|window| window == b"\r\n\r\n")
        .map(|index| index + 4)
}

fn read_http_body(stream: &mut TcpStream) -> Result<Vec<u8>> {
    let mut data = Vec::with_capacity(16 * 1024);
    let mut buffer = [0u8; 8192];

    let header_end = loop {
        let read = stream.read(&mut buffer)?;
        if read == 0 {
            return Err(io::Error::new(
                io::ErrorKind::UnexpectedEof,
                "connection closed before HTTP headers",
            )
            .into());
        }

        data.extend_from_slice(&buffer[..read]);

        if let Some(end) = find_header_end(&data) {
            break end;
        }

        if data.len() > 64 * 1024 {
            return Err(
                io::Error::new(io::ErrorKind::InvalidData, "HTTP headers too large").into(),
            );
        }
    };

    let headers = std::str::from_utf8(&data[..header_end])?;

    let content_length = headers
        .lines()
        .find_map(|line| {
            let (name, value) = line.split_once(':')?;
            if name.eq_ignore_ascii_case("content-length") {
                value.trim().parse::<usize>().ok()
            } else {
                None
            }
        })
        .ok_or_else(|| io::Error::other("missing Content-Length"))?;

    if headers.lines().any(|line| {
        line.split_once(':').is_some_and(|(name, value)| {
            name.eq_ignore_ascii_case("expect") && value.trim().eq_ignore_ascii_case("100-continue")
        })
    }) {
        stream.write_all(b"HTTP/1.1 100 Continue\r\n\r\n")?;
        stream.flush()?;
    }

    if content_length > 2 * 1024 * 1024 {
        return Err(io::Error::new(io::ErrorKind::InvalidData, "request body too large").into());
    }

    let needed = header_end + content_length;
    while data.len() < needed {
        let read = stream.read(&mut buffer)?;
        if read == 0 {
            return Err(
                io::Error::new(io::ErrorKind::UnexpectedEof, "incomplete HTTP body").into(),
            );
        }
        data.extend_from_slice(&buffer[..read]);
    }

    Ok(data[header_end..needed].to_vec())
}

fn log_whisrs_output(response: &[u8]) {
    eprintln!("--- WHISRS OUTPUT ---");

    let body = response
        .windows(4)
        .position(|window| window == b"\r\n\r\n")
        .map_or(response, |position| &response[position + 4..]);

    match serde_json::from_slice::<Value>(body)
        .ok()
        .and_then(|value| {
            value["choices"][0]["message"]["content"]
                .as_str()
                .map(str::to_owned)
        }) {
        Some(output) => eprintln!("{output}"),
        None => eprintln!("{}", String::from_utf8_lossy(body)),
    }
}

fn forward_to_llama(client: &mut TcpStream, body: &[u8]) -> Result<()> {
    let mut upstream = TcpStream::connect(LLAMA_ADDR)?;

    write!(
        upstream,
        concat!(
            "POST /v1/chat/completions HTTP/1.1\r\n",
            "Host: 127.0.0.1:2813\r\n",
            "Content-Type: application/json\r\n",
            "Content-Length: {}\r\n",
            "Connection: close\r\n",
            "\r\n"
        ),
        body.len(),
    )?;

    upstream.write_all(body)?;
    upstream.flush()?;
    let mut response = Vec::new();
    upstream.read_to_end(&mut response)?;
    log_whisrs_output(&response);
    client.write_all(&response)?;
    client.flush()?;
    Ok(())
}

fn error_response(stream: &mut TcpStream, error: &dyn std::fmt::Display) {
    let body = format!("context proxy error: {error}\n");
    let _ = write!(
        stream,
        concat!(
            "HTTP/1.1 500 Internal Server Error\r\n",
            "Content-Type: text/plain\r\n",
            "Content-Length: {}\r\n",
            "Connection: close\r\n",
            "\r\n",
            "{}"
        ),
        body.len(),
        body,
    );
}

fn handle_proxy_client(
    mut client: TcpStream,
    config: Arc<RuntimeConfig>,
    dotool: Arc<Mutex<Dotool>>,
) {
    let total = Instant::now();
    eprintln!("PROXY: accepted");

    let result = (|| -> Result<()> {
        let t = Instant::now();
        let body = read_http_body(&mut client)?;
        eprintln!("PROXY: body complete {:?}", t.elapsed());

        eprintln!("--- WHISRS INPUT ---");
        eprintln!("{}", String::from_utf8_lossy(&body));

        let t = Instant::now();
        let snapshot = Snapshot::capture()?;
        let context = context_for(&config, &snapshot);
        eprintln!("PROXY: context capture {:?}", t.elapsed());

        if let Some(matched) = apply_transform(&config, &snapshot, &body)? {
            eprintln!(
                "PROXY: transform {} -> {:?} submit={}",
                matched.rule, matched.output, matched.submit
            );

            for action in &matched.actions_before {
                match action {
                    TransformAction::Key(key) => {
                        dotool
                            .lock()
                            .map_err(|_| io::Error::other("dotool mutex poisoned"))?
                            .key(key)?;
                    }
                    TransformAction::Wait(milliseconds) => {
                        thread::sleep(std::time::Duration::from_millis(*milliseconds));
                    }
                }
            }

            transformed_response(&mut client, &matched.output)?;

            if matched.submit {
                thread::sleep(std::time::Duration::from_millis(config.submit_delay_ms));
                dotool
                    .lock()
                    .map_err(|_| io::Error::other("dotool mutex poisoned"))?
                    .key("enter")?;
            }

            return Ok(());
        }

        if !config.llm_enabled {
            let text = selected_text(&body)?.ok_or_else(|| {
                io::Error::new(io::ErrorKind::InvalidData, "missing dictated text")
            })?;
            transformed_response(&mut client, &text)?;
            return Ok(());
        }

        eprintln!("--- CONTEXT ---");
        eprintln!("{context}");

        let t = Instant::now();
        let body = inject_context(&body, &context)?;
        eprintln!("PROXY: JSON injection {:?}", t.elapsed());

        let t = Instant::now();
        forward_to_llama(&mut client, &body)?;
        eprintln!("PROXY: forward complete {:?}", t.elapsed());

        Ok(())
    })();

    eprintln!("PROXY: total {:?}", total.elapsed());

    if let Err(error) = result {
        eprintln!("PROXY ERROR: {error}");
        error_response(&mut client, error.as_ref());
    }
}

fn run_proxy(config_path: &Path, dotool_path: &Path) -> Result<()> {
    let config = Arc::new(RuntimeConfig::load(config_path)?);
    let dotool = Arc::new(Mutex::new(Dotool::start(dotool_path)?));
    let listener = TcpListener::bind(PROXY_LISTEN)?;

    for client in listener.incoming() {
        match client {
            Ok(client) => {
                let config = Arc::clone(&config);
                let dotool = Arc::clone(&dotool);
                thread::spawn(move || handle_proxy_client(client, config, dotool));
            }
            Err(error) => eprintln!("PROXY accept error: {error}"),
        }
    }

    Ok(())
}

struct Dotool {
    _child: Child,
    stdin: ChildStdin,
}

impl Dotool {
    fn start(path: &Path) -> Result<Self> {
        let mut child = Command::new(path)
            .stdin(Stdio::piped())
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .spawn()?;
        let stdin = child
            .stdin
            .take()
            .ok_or_else(|| io::Error::other("dotool stdin unavailable"))?;
        Ok(Self {
            _child: child,
            stdin,
        })
    }

    fn key(&mut self, key: &str) -> Result<()> {
        writeln!(self.stdin, "key {key}")?;
        self.stdin.flush()?;
        Ok(())
    }
}

fn strip_ansi(input: &str) -> String {
    let bytes = input.as_bytes();
    let mut out = String::with_capacity(input.len());
    let mut i = 0;

    while i < bytes.len() {
        if bytes[i] == 0x1b && bytes.get(i + 1) == Some(&b'[') {
            i += 2;
            while i < bytes.len() {
                let b = bytes[i];
                i += 1;
                if (b as char).is_ascii_alphabetic() {
                    break;
                }
            }
        } else {
            out.push(bytes[i] as char);
            i += 1;
        }
    }

    out
}

fn detected_command(line: &str) -> Option<String> {
    let line = strip_ansi(line);
    let marker = "detected command: ";
    let start = line.find(marker)? + marker.len();
    let rest = &line[start..];
    let end = rest.find(" | p =")?;
    Some(rest[..end].trim().to_owned())
}

fn select_command_action(
    config: &RuntimeConfig,
    command: &str,
) -> Result<Option<(String, String)>> {
    let candidates = config
        .command_modes
        .iter()
        .filter(|mode| mode.commands.contains_key(command))
        .collect::<Vec<_>>();

    if !candidates.is_empty() {
        let snapshot = Snapshot::capture()?;
        for mode in candidates {
            if mode.matcher.matches(&snapshot) {
                return Ok(mode
                    .commands
                    .get(command)
                    .cloned()
                    .map(|action| (action, mode.name.clone())));
            }
        }
    }

    Ok(config
        .command_default
        .get(command)
        .cloned()
        .map(|action| (action, "default".to_owned())))
}

fn focus_app(pattern: &str) -> Result<()> {
    let regex = RegexBuilder::new(pattern).case_insensitive(true).build()?;
    let windows_response = niri_request(json!("Windows"))?;
    let windows = windows_response
        .get("Windows")
        .and_then(Value::as_array)
        .ok_or_else(|| io::Error::other("invalid Windows response"))?;

    let mut best: Option<(i64, i64, u64)> = None;

    for window in windows {
        let Some(app_id) = window.get("app_id").and_then(Value::as_str) else {
            continue;
        };
        if !regex.is_match(app_id) {
            continue;
        }

        let Some(id) = window.get("id").and_then(Value::as_u64) else {
            continue;
        };

        let timestamp = window.get("focus_timestamp");
        let secs = timestamp
            .and_then(|value| value.get("secs"))
            .and_then(Value::as_i64)
            .unwrap_or(-1);
        let nanos = timestamp
            .and_then(|value| value.get("nanos"))
            .and_then(Value::as_i64)
            .unwrap_or(-1);

        let is_newer = match best {
            None => true,
            Some(current) => (secs, nanos).cmp(&(current.0, current.1)) == Ordering::Greater,
        };
        if is_newer {
            best = Some((secs, nanos, id));
        }
    }

    if let Some((_, _, id)) = best {
        let _ = niri_request(json!({
            "Action": {
                "FocusWindow": {
                    "id": id
                }
            }
        }))?;
    }

    Ok(())
}

fn split_action_segments(action: &str) -> Result<Vec<String>> {
    let mut segments = Vec::new();
    let mut current = String::new();
    let mut quote: Option<char> = None;
    let mut escaped = false;

    for ch in action.chars() {
        if escaped {
            current.push(ch);
            escaped = false;
            continue;
        }

        if ch == '\\' && quote != Some('\'') {
            current.push(ch);
            escaped = true;
            continue;
        }

        match quote {
            Some(q) if ch == q => {
                current.push(ch);
                quote = None;
            }
            Some(_) => current.push(ch),
            None if ch == '\'' || ch == '"' => {
                current.push(ch);
                quote = Some(ch);
            }
            None if ch == ';' => {
                if !current.trim().is_empty() {
                    segments.push(current.trim().to_owned());
                }
                current.clear();
            }
            None => current.push(ch),
        }
    }

    if quote.is_some() || escaped {
        return Err(io::Error::other("unterminated quote or escape in action").into());
    }

    if !current.trim().is_empty() {
        segments.push(current.trim().to_owned());
    }

    Ok(segments)
}

fn split_words(input: &str) -> Result<Vec<String>> {
    let mut words = Vec::new();
    let mut current = String::new();
    let mut quote: Option<char> = None;
    let mut escaped = false;

    for ch in input.chars() {
        if escaped {
            current.push(ch);
            escaped = false;
            continue;
        }

        match quote {
            Some('\'') => {
                if ch == '\'' {
                    quote = None;
                } else {
                    current.push(ch);
                }
            }
            Some('"') => {
                if ch == '"' {
                    quote = None;
                } else if ch == '\\' {
                    escaped = true;
                } else {
                    current.push(ch);
                }
            }
            Some(_) => unreachable!(),
            None => match ch {
                '\'' | '"' => quote = Some(ch),
                '\\' => escaped = true,
                ch if ch.is_whitespace() => {
                    if !current.is_empty() {
                        words.push(std::mem::take(&mut current));
                    }
                }
                _ => current.push(ch),
            },
        }
    }

    if quote.is_some() || escaped {
        return Err(io::Error::other("unterminated quote or escape in action").into());
    }

    if !current.is_empty() {
        words.push(current);
    }

    Ok(words)
}

fn execute_action(action: &str, dotool: &mut Dotool) -> Result<()> {
    for segment in split_action_segments(action)? {
        let words = split_words(&segment)?;
        if words.is_empty() {
            continue;
        }

        match words[0].as_str() {
            "key" => {
                if words.len() < 2 {
                    return Err(io::Error::other("key action requires an argument").into());
                }
                dotool.key(&words[1..].join(" "))?;
            }
            "focus_app" => {
                if words.len() != 2 {
                    return Err(io::Error::other("focus_app requires exactly one regex").into());
                }
                focus_app(&words[1])?;
            }
            executable => {
                let status = Command::new(executable).args(&words[1..]).status()?;
                if !status.success() {
                    eprintln!("VOICE action exited with {status}: {segment}");
                }
            }
        }
    }

    Ok(())
}

struct CommandArgs {
    config: PathBuf,
    whisper: PathBuf,
    model: PathBuf,
    command_list: PathBuf,
    dotool: PathBuf,
    gate: PathBuf,
    poll_ms: u32,
    audio_ms: u32,
    vad_ms: u32,
    startup_ms: u32,
    audio_ctx: u32,
    threads: u32,
    vad_threshold: f32,
}

fn run_commands(args: CommandArgs) -> Result<()> {
    let config = RuntimeConfig::load(&args.config)?;
    let _ = fs::remove_file(&args.gate);

    let mut dotool = Dotool::start(&args.dotool)?;

    let mut child = Command::new(&args.whisper)
        .arg("-m")
        .arg(&args.model)
        .arg("-cmd")
        .arg(&args.command_list)
        .arg("-ac")
        .arg(args.audio_ctx.to_string())
        .arg("-t")
        .arg(args.threads.to_string())
        .arg("-vth")
        .arg(args.vad_threshold.to_string())
        .env("WHISPER_COMMAND_GATE_FILE", &args.gate)
        .env("WHISPER_COMMAND_POLL_MS", args.poll_ms.to_string())
        .env("WHISPER_COMMAND_AUDIO_MS", args.audio_ms.to_string())
        .env("WHISPER_COMMAND_VAD_MS", args.vad_ms.to_string())
        .env("WHISPER_COMMAND_STARTUP_MS", args.startup_ms.to_string())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()?;

    let stdout = child
        .stdout
        .take()
        .ok_or_else(|| io::Error::other("whisper-command stdout unavailable"))?;

    for line in BufReader::new(stdout).lines() {
        let line = line?;
        let Some(command) = detected_command(&line) else {
            continue;
        };

        if !args.gate.exists() {
            continue;
        }

        let t = Instant::now();
        match select_command_action(&config, &command)? {
            Some((action, mode)) => {
                eprintln!("VOICE: {command:?} mode={mode} match={:?}", t.elapsed());
                let t = Instant::now();
                execute_action(&action, &mut dotool)?;
                eprintln!("VOICE: action {:?}", t.elapsed());
            }
            None => eprintln!("VOICE: no action for {command:?}"),
        }
    }

    let status = child.wait()?;
    Err(io::Error::other(format!("whisper-command exited with {status}")).into())
}

struct MidiArgs {
    port: String,
    whisrs: PathBuf,
    dotool: PathBuf,
    gate: PathBuf,
    command_note: u8,
    german_note: u8,
    enter_note: u8,
    dictation_note: u8,
}

struct AlsaSequencer(*mut SndSeq);

impl Drop for AlsaSequencer {
    fn drop(&mut self) {
        // SAFETY: the handle was returned by snd_seq_open and is owned here.
        unsafe {
            snd_seq_close(self.0);
        }
    }
}

fn alsa_result(operation: &str, code: c_int) -> Result<c_int> {
    if code >= 0 {
        return Ok(code);
    }
    // SAFETY: ALSA returns a static NUL-terminated description for its error.
    let detail = unsafe { CStr::from_ptr(snd_strerror(code)) }.to_string_lossy();
    Err(io::Error::other(format!("{operation}: {detail}")).into())
}

fn open_exclusive_midi(port_name: &str) -> Result<AlsaSequencer> {
    let mut handle = std::ptr::null_mut();
    let default = CString::new("default")?;
    // SAFETY: all pointers are valid and ALSA initializes handle on success.
    alsa_result("open ALSA sequencer", unsafe {
        snd_seq_open(&mut handle, default.as_ptr(), SND_SEQ_OPEN_INPUT, 0)
    })?;
    let seq = AlsaSequencer(handle);

    let client_name = CString::new("voice-control-midi")?;
    let input_name = CString::new("exclusive-input")?;
    // SAFETY: seq is live and both strings remain valid for these calls.
    alsa_result("name ALSA client", unsafe {
        snd_seq_set_client_name(seq.0, client_name.as_ptr())
    })?;
    let local_port = alsa_result("create ALSA input port", unsafe {
        snd_seq_create_simple_port(
            seq.0,
            input_name.as_ptr(),
            SND_SEQ_PORT_CAP_WRITE | SND_SEQ_PORT_CAP_SUBS_WRITE,
            SND_SEQ_PORT_TYPE_MIDI_GENERIC | SND_SEQ_PORT_TYPE_APPLICATION,
        )
    })?;
    let client = alsa_result("get ALSA client id", unsafe { snd_seq_client_id(seq.0) })?;

    let mut sender = SndSeqAddr { client: 0, port: 0 };
    let port_name = CString::new(port_name)?;
    alsa_result("resolve MIDI source", unsafe {
        snd_seq_parse_address(seq.0, &mut sender, port_name.as_ptr())
    })?;
    let destination = SndSeqAddr {
        client: u8::try_from(client)?,
        port: u8::try_from(local_port)?,
    };

    let mut subscription = std::ptr::null_mut();
    alsa_result("allocate ALSA subscription", unsafe {
        snd_seq_port_subscribe_malloc(&mut subscription)
    })?;
    // SAFETY: subscription is allocated, addresses are valid for the calls,
    // and ALSA copies the subscription data before the container is freed.
    let subscribe_result = unsafe {
        snd_seq_port_subscribe_set_sender(subscription, &sender);
        snd_seq_port_subscribe_set_dest(subscription, &destination);
        snd_seq_port_subscribe_set_exclusive(subscription, 1);
        let result = snd_seq_subscribe_port(seq.0, subscription);
        snd_seq_port_subscribe_free(subscription);
        result
    };
    alsa_result("acquire exclusive MIDI subscription", subscribe_result)?;
    eprintln!(
        "exclusively connected MIDI source {}:{} to voice-control-midi",
        sender.client, sender.port
    );
    Ok(seq)
}

fn run_quiet(program: &Path, arguments: &[&str]) -> Result<()> {
    let status = Command::new(program)
        .args(arguments)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .status()?;
    if status.success() {
        Ok(())
    } else {
        Err(io::Error::other(format!(
            "{} {} failed with {status}",
            program.display(),
            arguments.join(" ")
        ))
        .into())
    }
}

fn send_dotool(dotool: &Path, command: &str) -> Result<()> {
    let mut child = Command::new(dotool)
        .stdin(Stdio::piped())
        .stdout(Stdio::null())
        .spawn()?;
    child
        .stdin
        .take()
        .ok_or_else(|| io::Error::other("dotool stdin unavailable"))?
        .write_all(command.as_bytes())?;
    let status = child.wait()?;
    if status.success() {
        Ok(())
    } else {
        Err(io::Error::other(format!("dotool failed with {status}")).into())
    }
}

fn handle_midi_edge(args: &MidiArgs, note: u8, pressed: bool) -> Result<()> {
    if note == args.command_note {
        if pressed {
            fs::write(&args.gate, [])?;
        } else if let Err(error) = fs::remove_file(&args.gate)
            && error.kind() != io::ErrorKind::NotFound
        {
            return Err(error.into());
        }
    } else if note == args.german_note {
        if pressed {
            run_quiet(&args.whisrs, &["start", "-l", "de"])?;
        } else {
            run_quiet(&args.whisrs, &["stop"])?;
        }
    } else if note == args.dictation_note {
        if pressed {
            run_quiet(&args.whisrs, &["start", "-l", "en"])?;
        } else {
            run_quiet(&args.whisrs, &["stop"])?;
        }
    } else if note == args.enter_note {
        send_dotool(
            &args.dotool,
            if pressed {
                "keydown enter\n"
            } else {
                "keyup enter\n"
            },
        )?;
    }
    Ok(())
}

fn midi_events(port: &str, tx: &std::sync::mpsc::Sender<(u8, bool)>) -> Result<()> {
    let seq = open_exclusive_midi(port)?;
    let mut pressed = [false; 128];

    loop {
        let mut event = std::ptr::null_mut();
        // SAFETY: seq remains open and ALSA owns the returned event until the
        // next input call. We copy the fixed note payload before then.
        alsa_result("read MIDI event", unsafe {
            snd_seq_event_input(seq.0, &mut event)
        })?;
        if event.is_null() {
            continue;
        }
        let event = unsafe { &*event };
        if event.event_type != SND_SEQ_EVENT_NOTEON && event.event_type != SND_SEQ_EVENT_NOTEOFF {
            continue;
        }
        let note_event = unsafe { event.data.note };
        let is_pressed = event.event_type == SND_SEQ_EVENT_NOTEON && note_event.velocity != 0;
        let index = usize::from(note_event.note);
        if pressed[index] == is_pressed {
            continue;
        }
        pressed[index] = is_pressed;
        tx.send((note_event.note, is_pressed))?;
    }
}

// Linux EVIOCGKEY(32): read held keys without taking events from niri.
const EVIOCGKEY: c_ulong = 0x8020_4518;

unsafe extern "C" {
    fn ioctl(fd: c_int, request: c_ulong, ...) -> c_int;
}

fn shortcut_keys(spec: &str) -> Result<(usize, Vec<[usize; 2]>)> {
    let parts = spec.split('+').collect::<Vec<_>>();
    let (key, mods) = parts
        .split_last()
        .ok_or_else(|| io::Error::other("empty shortcut"))?;
    let letter = key.trim().to_ascii_uppercase();
    let index = b"ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        .iter()
        .position(|ch| Some(*ch) == letter.as_bytes().first().copied())
        .filter(|_| letter.len() == 1)
        .ok_or_else(|| io::Error::other(format!("unsupported shortcut key: {key}")))?;
    // Linux key codes for letter keys. A stays on code 30 in Colemak.
    let letters = [
        30, 48, 46, 32, 18, 33, 34, 35, 23, 36, 37, 38, 50, 49, 24, 25, 16, 19, 31, 20, 22, 47, 17,
        45, 21, 44,
    ];
    let mut modifiers = Vec::new();
    for modifier in mods {
        modifiers.push(match modifier.trim().to_ascii_lowercase().as_str() {
            "mod" | "super" => [125, 126],
            "alt" => [56, 100],
            "ctrl" | "control" => [29, 97],
            "shift" => [42, 54],
            _ => return Err(io::Error::other(format!("unsupported modifier: {modifier}")).into()),
        });
    }
    if modifiers.is_empty() {
        return Err(io::Error::other("shortcut needs a modifier").into());
    }
    Ok((letters[index], modifiers))
}

fn held_keys(devices: &[std::fs::File]) -> [bool; 256] {
    use std::os::fd::AsRawFd;

    let mut held = [false; 256];
    for device in devices {
        let mut bits = [0u8; 32];
        // SAFETY: bits is a writable buffer of the size requested above.
        if unsafe { ioctl(device.as_raw_fd(), EVIOCGKEY, bits.as_mut_ptr()) } < 0 {
            continue;
        }
        for (code, is_held) in held.iter_mut().enumerate() {
            *is_held |= bits[code / 8] & (1 << (code % 8)) != 0;
        }
    }
    held
}

fn matches_shortcut(held: &[bool; 256], key: usize, modifiers: &[[usize; 2]]) -> bool {
    let modifier_keys = [[125, 126], [56, 100], [29, 97], [42, 54]];
    held[key]
        && modifier_keys
            .iter()
            .all(|pair| (held[pair[0]] || held[pair[1]]) == modifiers.contains(pair))
}

fn run_controls(args: MidiArgs, english: &str, german: &str) -> Result<()> {
    let bindings = [
        (shortcut_keys(english)?, "en"),
        (shortcut_keys(german)?, "de"),
    ];
    let devices = fs::read_dir("/dev/input")?
        .filter_map(|entry| entry.ok())
        .filter(|entry| entry.file_name().to_string_lossy().starts_with("event"))
        .filter_map(|entry| std::fs::File::open(entry.path()).ok())
        .collect::<Vec<_>>();
    if devices.is_empty() {
        eprintln!("no readable keyboard input devices; MIDI remains active");
    }
    let (tx, rx) = std::sync::mpsc::channel();
    let port = args.port.clone();
    thread::spawn(move || {
        loop {
            if let Err(error) = midi_events(&port, &tx) {
                eprintln!("MIDI listener failed: {error}");
                thread::sleep(std::time::Duration::from_secs(1));
            }
        }
    });
    let mut active: Option<usize> = None;
    let mut key_was_held = [false; 2];
    loop {
        while let Ok((note, pressed)) = rx.try_recv() {
            if let Err(error) = handle_midi_edge(&args, note, pressed) {
                eprintln!("MIDI note {note} action failed: {error}");
            }
        }
        let held = held_keys(&devices);
        if let Some(index) = active {
            let (binding, _) = &bindings[index];
            if !matches_shortcut(&held, binding.0, &binding.1) {
                active = None;
                if let Err(error) = run_quiet(&args.whisrs, &["stop"]) {
                    eprintln!("keyboard dictation stop failed: {error}");
                }
            }
        }
        if active.is_none()
            && let Some(index) =
                bindings
                    .iter()
                    .enumerate()
                    .position(|(index, ((key, modifiers), _))| {
                        matches_shortcut(&held, *key, modifiers) && !key_was_held[index]
                    })
        {
            active = Some(index);
            if let Err(error) = run_quiet(&args.whisrs, &["start", "-l", bindings[index].1]) {
                eprintln!("keyboard dictation start failed: {error}");
            }
        }
        for (index, ((key, _), _)) in bindings.iter().enumerate() {
            key_was_held[index] = held[*key];
        }
        thread::sleep(std::time::Duration::from_millis(10));
    }
}

fn value_after(args: &[String], name: &str) -> Result<String> {
    let index = args
        .iter()
        .position(|arg| arg == name)
        .ok_or_else(|| io::Error::other(format!("missing {name}")))?;
    args.get(index + 1)
        .cloned()
        .ok_or_else(|| io::Error::other(format!("missing value for {name}")).into())
}

fn parse_value<T>(args: &[String], name: &str) -> Result<T>
where
    T: std::str::FromStr,
    T::Err: std::fmt::Display + Send + Sync + 'static,
{
    let value = value_after(args, name)?;
    value.parse::<T>().map_err(|error| {
        io::Error::other(format!("invalid {name} value {value:?}: {error}")).into()
    })
}

fn usage() -> ! {
    eprintln!(
        "usage:\n  voice-control-runtime proxy --config FILE --dotool FILE\n  voice-control-runtime commands --config FILE --whisper FILE --model FILE --command-list FILE --dotool FILE --gate FILE --poll-ms N --audio-ms N --vad-ms N --startup-ms N --audio-ctx N --threads N --vad-threshold N\n  voice-control-runtime controls --port CLIENT[:PORT] --whisrs FILE --dotool FILE --gate FILE --command-note N --german-note N --enter-note N --dictation-note N --english Mod+A --german Mod+Shift+A"
    );
    std::process::exit(2);
}

fn main() -> Result<()> {
    let args = env::args().collect::<Vec<_>>();
    let Some(mode) = args.get(1).map(String::as_str) else {
        usage();
    };

    match mode {
        "proxy" => {
            let config = PathBuf::from(value_after(&args, "--config")?);
            let dotool = PathBuf::from(value_after(&args, "--dotool")?);
            run_proxy(&config, &dotool)
        }
        "commands" => run_commands(CommandArgs {
            config: PathBuf::from(value_after(&args, "--config")?),
            whisper: PathBuf::from(value_after(&args, "--whisper")?),
            model: PathBuf::from(value_after(&args, "--model")?),
            command_list: PathBuf::from(value_after(&args, "--command-list")?),
            dotool: PathBuf::from(value_after(&args, "--dotool")?),
            gate: PathBuf::from(value_after(&args, "--gate")?),
            poll_ms: parse_value(&args, "--poll-ms")?,
            audio_ms: parse_value(&args, "--audio-ms")?,
            vad_ms: parse_value(&args, "--vad-ms")?,
            startup_ms: parse_value(&args, "--startup-ms")?,
            audio_ctx: parse_value(&args, "--audio-ctx")?,
            threads: parse_value(&args, "--threads")?,
            vad_threshold: parse_value(&args, "--vad-threshold")?,
        }),
        "controls" => run_controls(
            MidiArgs {
                port: value_after(&args, "--port")?,
                whisrs: PathBuf::from(value_after(&args, "--whisrs")?),
                dotool: PathBuf::from(value_after(&args, "--dotool")?),
                gate: PathBuf::from(value_after(&args, "--gate")?),
                command_note: parse_value(&args, "--command-note")?,
                german_note: parse_value(&args, "--german-note")?,
                enter_note: parse_value(&args, "--enter-note")?,
                dictation_note: parse_value(&args, "--dictation-note")?,
            },
            &value_after(&args, "--english")?,
            &value_after(&args, "--german")?,
        ),
        _ => usage(),
    }
}

#[cfg(test)]
mod tests {
    use super::{
        Transform, TransformAction, matches_shortcut, normalize_process_name, replacement_actions,
        selected_text, shortcut_keys,
    };
    use regex::Regex;
    use serde_json::json;

    #[test]
    fn parses_held_shortcut() {
        assert_eq!(shortcut_keys("Mod+A").unwrap(), (30, vec![[125, 126]]));
        assert_eq!(
            shortcut_keys("Mod+Shift+A").unwrap(),
            (30, vec![[125, 126], [42, 54]])
        );
        assert!(shortcut_keys("A").is_err());
        assert!(shortcut_keys("Mod+F24").is_err());
    }

    #[test]
    fn shifted_shortcut_does_not_trigger_english() {
        let mut held = [false; 256];
        held[30] = true;
        held[125] = true;
        held[42] = true;
        assert!(!matches_shortcut(&held, 30, &[[125, 126]]));
        assert!(matches_shortcut(&held, 30, &[[125, 126], [42, 54]]));
    }

    #[test]
    fn normalizes_nix_wrapped_executable_names() {
        assert_eq!(normalize_process_name(".hx-wrapped\n"), "hx");
        assert_eq!(normalize_process_name(".helix-wrapped\n"), "helix");
    }

    #[test]
    fn preserves_regular_process_names() {
        assert_eq!(normalize_process_name("hx\n"), "hx");
        assert_eq!(normalize_process_name("kitty\n"), "kitty");
    }

    #[test]
    fn transform_requires_the_configured_full_match() {
        let transform = Transform {
            name: "slash-command".to_owned(),
            pattern: Regex::new(r"(?i)^\s*(status|usage)[.!?]?\s*$").unwrap(),
            replace: "/$1".to_owned(),
            lowercase: true,
            lowercase_first: false,
            trim_end_punctuation: false,
        };

        assert_eq!(transform.apply("Status."), Some("/status".to_owned()));
        assert_eq!(transform.apply("check the status"), None);
    }

    #[test]
    fn transform_replaces_every_match() {
        let transform = Transform {
            name: "words".to_owned(),
            pattern: Regex::new(r"(?i)\b(status|usage)\b").unwrap(),
            replace: "/$1".to_owned(),
            lowercase: true,
            lowercase_first: false,
            trim_end_punctuation: false,
        };

        assert_eq!(
            transform.apply("Status then usage"),
            Some("/status then /usage".to_owned())
        );
    }

    #[test]
    fn replacement_embeds_keys_and_submit() {
        let actions = replacement_actions("\\k{esc}\\w{150}needle\n".to_owned());

        assert_eq!(
            actions.actions_before,
            [
                TransformAction::Key("esc".to_owned()),
                TransformAction::Wait(150)
            ]
        );
        assert_eq!(actions.output, "needle");
        assert!(actions.submit);
    }

    #[test]
    fn leading_word_rule_does_not_match_the_middle_of_a_sentence() {
        let transform = Transform {
            name: "find".to_owned(),
            pattern: Regex::new(r"(?i)^\s*(?:find|search)\s+(.+?)\s*$").unwrap(),
            replace: r"\k{esc}/$1".to_owned(),
            lowercase: false,
            lowercase_first: false,
            trim_end_punctuation: false,
        };

        assert_eq!(
            transform.apply("find StructName"),
            Some(r"\k{esc}/StructName".to_owned())
        );
        assert_eq!(transform.apply("please find StructName"), None);
    }

    #[test]
    fn extracts_whisrs_selected_text() {
        let body = serde_json::to_vec(&json!({
            "messages": [{
                "role": "user",
                "content": "Selected text:\nusage\n\nInstruction: clean it"
            }]
        }))
        .unwrap();

        assert_eq!(selected_text(&body).unwrap(), Some("usage".to_owned()));
    }
}
