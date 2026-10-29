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
    #[serde(default)]
    exclude_pattern: Option<String>,
    replace: String,
    #[serde(default)]
    lowercase: bool,
    #[serde(default)]
    whole_session_only: bool,
    #[serde(default)]
    session_start_only: bool,
    #[serde(default)]
    exclude_languages: Vec<String>,
    #[serde(default)]
    spoken_punctuation: String,
    #[serde(default)]
    after_modes: bool,
    #[serde(default)]
    lowercase_first: bool,
    #[serde(default)]
    lowercase_first_whole_session: bool,
    #[serde(default)]
    german_max_words: Option<usize>,
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
    exclude_pattern: Option<Regex>,
    replace: String,
    lowercase: bool,
    whole_session_only: bool,
    session_start_only: bool,
    exclude_languages: Vec<String>,
    spoken_punctuation: String,
    after_modes: bool,
    lowercase_first: bool,
    lowercase_first_whole_session: bool,
    german_max_words: Option<usize>,
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
            exclude_pattern: raw
                .exclude_pattern
                .map(|pattern| Regex::new(&pattern))
                .transpose()?,
            replace: raw.replace,
            lowercase: raw.lowercase,
            whole_session_only: raw.whole_session_only,
            session_start_only: raw.session_start_only,
            exclude_languages: raw.exclude_languages,
            spoken_punctuation: raw.spoken_punctuation,
            after_modes: raw.after_modes,
            lowercase_first: raw.lowercase_first,
            lowercase_first_whole_session: raw.lowercase_first_whole_session,
            german_max_words: raw.german_max_words,
            trim_end_punctuation: raw.trim_end_punctuation,
        })
    }

    #[cfg(test)]
    fn apply(&self, input: &str) -> Option<String> {
        self.apply_in_session(input, None)
    }

    fn apply_in_session(&self, input: &str, session: Option<&DictationSession>) -> Option<String> {
        if self.session_start_only && session.is_some_and(|session| !session.session_start) {
            return None;
        }
        if self.whole_session_only && !session.is_some_and(|session| session.whole_session) {
            return None;
        }
        if session.is_some_and(|session| self.exclude_languages.contains(&session.language)) {
            return None;
        }
        if self
            .exclude_pattern
            .as_ref()
            .is_some_and(|pattern| pattern.is_match(input))
            || !self.pattern.is_match(input)
        {
            return None;
        }

        let mut output = self
            .pattern
            .replace_all(input, self.replace.as_str())
            .into_owned();
        if matches!(self.spoken_punctuation.as_str(), "shell" | "identifier") {
            output = normalize_spoken_punctuation(&output, self.spoken_punctuation == "shell");
        }
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
        let may_lowercase_first = !self.lowercase_first_whole_session
            || session.is_some_and(|session| {
                session.whole_session
                    && (session.language != "de"
                        || self
                            .german_max_words
                            .is_none_or(|limit| input.split_whitespace().count() <= limit))
            });
        if self.lowercase_first && may_lowercase_first {
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

fn normalize_spoken_punctuation(input: &str, shell: bool) -> String {
    use std::sync::OnceLock;
    static COLON: OnceLock<Regex> = OnceLock::new();
    let colonized = COLON
        .get_or_init(|| Regex::new(r"(?i)[\s,]*\bcolon\b,?").unwrap())
        .replace_all(input, ":");
    let input = colonized.as_ref();
    let zoxide_query = shell && input.starts_with("z ");
    // Dot and underscore are explicitly requested even inside quotes. Run after
    // short-utterance cleanup so spoken dots cannot be mistaken for ASR periods.
    static Z_DOT: OnceLock<Regex> = OnceLock::new();
    static SEPARATOR_ONLY: OnceLock<Regex> = OnceLock::new();
    static SEPARATORS: OnceLock<Regex> = OnceLock::new();
    static COMMAND_HEAD: OnceLock<Regex> = OnceLock::new();
    if Z_DOT
        .get_or_init(|| Regex::new(r"(?i)^\s*z\s+dot[.!?]*\s*$").unwrap())
        .is_match(input)
    {
        return input.to_owned();
    }
    if let Some(separator) = SEPARATOR_ONLY
        .get_or_init(|| Regex::new(r"(?i)^\s*(dot|under[ -]?score)[.!?]*\s*$").unwrap())
        .captures(input)
    {
        return if separator[1].eq_ignore_ascii_case("dot") {
            "."
        } else {
            "_"
        }
        .into();
    }
    // Process both separators together: joining underscore first would hide the
    // word boundary in "file underscore dot rs" and prevent dot conversion.
    let separators = SEPARATORS
        .get_or_init(|| Regex::new(r"(?i)[\s,]*\b(dot|under[ -]?score)\b[\s,]*").unwrap());
    let command_head = COMMAND_HEAD.get_or_init(|| Regex::new(
        r"(?i)^(?:git\s+\S+|cargo(?:\s+\S+)?|nix(?:\s+(?:flake\s+)?\S+)?|rg|fd|ll|ls|cd|hx|zathura|bat|cat|mkdir|rm|cp|mv|z|droix|codex|npm|pnpm|yarn|node|npx|bun|deno|tsc|trunk|ssh|rsync|curl|wget)$"
    ).unwrap());
    let mut dotted = String::new();
    let mut dot_end = 0;
    for separator in separators.captures_iter(input) {
        let found = separator.get(0).unwrap();
        dotted.push_str(&input[dot_end..found.start()]);
        if shell && command_head.is_match(&dotted) {
            dotted.push(' ');
        }
        dotted.push(if separator[1].eq_ignore_ascii_case("dot") {
            '.'
        } else {
            '_'
        });
        dot_end = found.end();
    }
    dotted.push_str(&input[dot_end..]);
    let input = dotted.as_str();
    static TOKENS: OnceLock<Regex> = OnceLock::new();
    let tokens = TOKENS.get_or_init(|| Regex::new(
        r#"(?i)"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|[\s,]*\b(?P<symbol>(?:(?:double|doppel)[\s,]+)?(?:dash|minus)|slash)\b[\s,]*"#
    ).unwrap());
    let mut output = String::new();
    let mut end = 0;
    for token in tokens.captures_iter(input) {
        let whole = token.get(0).unwrap();
        output.push_str(&input[end..whole.start()]);
        if let Some(symbol) = token.name("symbol") {
            let symbol = symbol.as_str().to_ascii_lowercase();
            if symbol == "slash" {
                if shell
                    && matches!(
                        output.as_str(),
                        "rg" | "fd" | "hx" | "cd" | "ls" | "ll" | "z" | "zathura" | "git clone"
                    )
                {
                    output.push(' ');
                }
                output.push('/');
            } else {
                if shell && !zoxide_query && !output.is_empty() && !output.ends_with('-') {
                    output.push(' ');
                }
                output.push('-');
                if symbol.starts_with("double") || symbol.starts_with("doppel") {
                    output.push('-');
                }
            }
        } else {
            // Explicitly quoted literals (including commit messages) are opaque.
            output.push_str(whole.as_str());
        }
        end = whole.end();
    }
    output.push_str(&input[end..]);
    if shell && output.starts_with("git ") {
        normalize_git_options(&output)
    } else {
        output
    }
}

fn normalize_git_options(input: &str) -> String {
    use std::sync::OnceLock;
    static TOKENS: OnceLock<Regex> = OnceLock::new();
    static OPTIONS: OnceLock<HashSet<&'static str>> = OnceLock::new();
    let options = OPTIONS.get_or_init(|| include_str!("git-long-options.txt").lines().collect());
    // Preserve shell tokens, including quoted arguments and escaped whitespace.
    let tokens = TOKENS
        .get_or_init(|| Regex::new(r#"(?:[^\s"'\\]|\\.|"(?:\\.|[^"\\])*"|'[^']*')+"#).unwrap());
    let tokens: Vec<_> = tokens.find_iter(input).collect();
    let mut output = String::new();
    let mut copied = 0;
    let mut index = 0;
    while index < tokens.len() {
        let token = tokens[index];
        if token.as_str() == "--" {
            break; // Everything after this is a path/revision, not an option.
        }
        let Some(first) = token.as_str().strip_prefix("--") else {
            index += 1;
            continue;
        };
        let mut candidate = String::new();
        let mut best = None;
        for (offset, part) in std::iter::once(first)
            .chain(tokens[index + 1..].iter().map(|token| token.as_str()))
            .take(8)
            .enumerate()
        {
            let (name, value) = part
                .split_once('=')
                .map_or((part, None), |(name, value)| (name, Some(value)));
            // A spoken internal "dash" is initially spaced like another option.
            // Rejoin it only when the complete result is a known Git long option.
            let name = if offset > 0 && !name.starts_with("--") {
                name.strip_prefix('-').unwrap_or(name)
            } else {
                name
            }
            .trim_end_matches(',');
            if name.is_empty()
                || name.starts_with('-')
                || !name.chars().all(|c| c.is_ascii_alphabetic() || c == '-')
            {
                break;
            }
            if offset > 0 {
                candidate.push('-');
            }
            candidate.push_str(&name.to_ascii_lowercase());
            if options.contains(candidate.as_str()) {
                let mut replacement = format!("--{candidate}");
                if let Some(value) = value {
                    replacement.push('=');
                    replacement.push_str(value);
                }
                best = Some((index + offset, replacement));
            }
            if value.is_some() {
                break;
            }
        }
        if let Some((last, replacement)) = best {
            output.push_str(&input[copied..token.start()]);
            output.push_str(&replacement);
            copied = tokens[last].end();
            index = last + 1;
        } else {
            index += 1;
        }
    }
    output.push_str(&input[copied..]);
    output
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct DictationSession {
    whole_session: bool,
    #[serde(default = "default_true")]
    session_start: bool,
    language: String,
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

fn discover_niri_stream(runtime_dir: &Path) -> Result<(UnixStream, PathBuf)> {
    let mut streams = Vec::new();
    for entry in fs::read_dir(runtime_dir)? {
        let entry = entry?;
        let name = entry.file_name();
        let name = name.to_string_lossy();
        if name.starts_with("niri.") && name.ends_with(".sock") {
            if let Ok(stream) = UnixStream::connect(entry.path()) {
                streams.push((stream, entry.path()));
            }
        }
    }
    if streams.len() != 1 {
        return Err(io::Error::other(format!(
            "expected one live niri socket in {}, found {}; set NIRI_SOCKET to select a session",
            runtime_dir.display(),
            streams.len()
        ))
        .into());
    }
    Ok(streams.pop().unwrap())
}

fn connect_niri() -> Result<(UnixStream, PathBuf)> {
    if let Some(socket) = env::var_os("NIRI_SOCKET") {
        let socket = PathBuf::from(socket);
        Ok((UnixStream::connect(&socket)?, socket))
    } else {
        // User services can start before niri imports its environment.
        let runtime_dir = env::var_os("XDG_RUNTIME_DIR")
            .ok_or_else(|| io::Error::other("XDG_RUNTIME_DIR is not set"))?;
        discover_niri_stream(Path::new(&runtime_dir))
    }
}

fn niri_request(request: Value) -> Result<Value> {
    let (mut stream, _) = connect_niri()?;
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
    let request: Value = serde_json::from_slice(body)?;
    let session = request
        .get("dictation")
        .map(|value| serde_json::from_value::<DictationSession>(value.clone()))
        .transpose()?;
    let mut matched_rules = Vec::new();
    for transform in config
        .dictation_transforms
        .iter()
        .filter(|rule| !rule.after_modes)
    {
        if let Some(transformed) = transform.apply_in_session(&output, session.as_ref()) {
            output = transformed;
            matched_rules.push(transform.name.clone());
        }
    }

    if let Some(mode) = active_transform_mode(config, snapshot) {
        for transform in &mode.transforms {
            if let Some(transformed) = transform.apply_in_session(&output, session.as_ref()) {
                output = transformed;
                matched_rules.push(format!("{}.{}", mode.name, transform.name));
            }
        }
    }

    for transform in config
        .dictation_transforms
        .iter()
        .filter(|rule| rule.after_modes)
    {
        if let Some(transformed) = transform.apply_in_session(&output, session.as_ref()) {
            output = transformed;
            matched_rules.push(transform.name.clone());
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
    object.remove("dictation");

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

        wait_for_keyboard_release();

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
        wait_for_keyboard_release();
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
                let mut process = Command::new(executable);
                process.args(&words[1..]);
                if Path::new(executable)
                    .file_name()
                    .is_some_and(|name| name == "niri")
                {
                    // Socket discovery must also reach CLI actions, not just context queries.
                    let (_, socket) = connect_niri()?;
                    process.env("NIRI_SOCKET", socket);
                }
                let status = process.status()?;
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
    no_gpu: bool,
}

fn run_commands(args: CommandArgs) -> Result<()> {
    let config = RuntimeConfig::load(&args.config)?;
    let _ = fs::remove_file(&args.gate);

    let mut dotool = Dotool::start(&args.dotool)?;

    let mut child = Command::new(&args.whisper)
        .args(if args.no_gpu { &["--no-gpu"][..] } else { &[] })
        .envs(args.no_gpu.then_some(("CUDA_VISIBLE_DEVICES", "")))
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

// Linux EVIOCGKEY(96): include mouse buttons (BTN_SIDE = 275) as well
// as keyboard keys, without taking events from niri.
const KEY_COUNT: usize = 768;
const EVIOCGKEY: c_ulong = 0x8060_4518;

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

fn held_keys(devices: &[std::fs::File]) -> [bool; KEY_COUNT] {
    use std::os::fd::AsRawFd;

    let mut held = [false; KEY_COUNT];
    for device in devices {
        let mut bits = [0u8; KEY_COUNT / 8];
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

fn matches_shortcut(held: &[bool; KEY_COUNT], key: usize, modifiers: &[[usize; 2]]) -> bool {
    // Mouse buttons are held independently of keyboard modifiers.
    if (272..=279).contains(&key) {
        return held[key];
    }
    let modifier_keys = [[125, 126], [56, 100], [29, 97], [42, 54]];
    held[key]
        && modifier_keys
            .iter()
            .all(|pair| (held[pair[0]] || held[pair[1]]) == modifiers.contains(pair))
}

fn wait_for_keyboard_release() {
    if let Some(path) = env::var_os("VOICE_CONTROL_KEYBOARD_GATE") {
        while Path::new(&path).exists() {
            thread::sleep(std::time::Duration::from_millis(10));
        }
    }
}

fn keyboard_output_blocked(held: &[bool; KEY_COUNT], keys: &[usize]) -> bool {
    keys.iter().any(|key| held[*key])
        || [125, 126, 56, 100, 29, 97, 42, 54]
            .iter()
            .any(|key| held[*key])
}

fn run_controls(
    args: MidiArgs,
    english: &str,
    german: &str,
    mouse_button: usize,
    german_mouse_button: usize,
    mouse_enabled: bool,
) -> Result<()> {
    if ![mouse_button, german_mouse_button]
        .iter()
        .all(|button| (272..=279).contains(button))
    {
        return Err(
            io::Error::other("mouse button must be a Linux button code from 272 to 279").into(),
        );
    }
    let mut bindings = vec![
        (shortcut_keys(english)?, "en"),
        (shortcut_keys(german)?, "de"),
        ((mouse_button, Vec::new()), "en"),
        ((german_mouse_button, Vec::new()), "de"),
    ];
    if !mouse_enabled {
        bindings.truncate(2);
    }
    let devices = fs::read_dir("/dev/input")?
        .filter_map(|entry| entry.ok())
        .filter(|entry| entry.file_name().to_string_lossy().starts_with("event"))
        .filter_map(|entry| std::fs::File::open(entry.path()).ok())
        .collect::<Vec<_>>();
    if devices.is_empty() {
        eprintln!("no readable keyboard input devices; MIDI remains active");
    }
    let devices = Arc::new(devices);
    let keyboard_gate = env::var_os("VOICE_CONTROL_KEYBOARD_GATE").map(PathBuf::from);
    let gate_lock = Arc::new(Mutex::new(()));
    if let Some(path) = keyboard_gate.clone() {
        let devices = Arc::clone(&devices);
        let gate_lock = Arc::clone(&gate_lock);
        let gate_bindings = [bindings[0].clone(), bindings[1].clone()];
        let keys = gate_bindings.each_ref().map(|((key, _), _)| *key);
        // Stop waits for transcription to drain, so release detection must
        // continue independently while the controls thread waits for stop.
        thread::spawn(move || {
            loop {
                {
                    let _guard = gate_lock.lock().unwrap();
                    let held = held_keys(&devices);
                    if gate_bindings
                        .iter()
                        .any(|((key, modifiers), _)| matches_shortcut(&held, *key, modifiers))
                        && !path.exists()
                    {
                        if let Err(error) = fs::write(&path, []) {
                            eprintln!("keyboard gate creation failed: {error}");
                        }
                    }
                    if !keyboard_output_blocked(&held, &keys) {
                        if let Err(error) = fs::remove_file(&path) {
                            if error.kind() != io::ErrorKind::NotFound {
                                eprintln!("keyboard gate cleanup failed: {error}");
                            }
                        }
                    }
                }
                thread::sleep(std::time::Duration::from_millis(10));
            }
        });
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
    let mut key_was_held = vec![false; bindings.len()];
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
            if index < 2
                && let Some(path) = &keyboard_gate
            {
                let _guard = gate_lock.lock().unwrap();
                fs::write(path, [])?;
            }
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
        "usage:\n  voice-control-runtime proxy --config FILE --dotool FILE\n  voice-control-runtime commands --config FILE --whisper FILE --model FILE --command-list FILE --dotool FILE --gate FILE --poll-ms N --audio-ms N --vad-ms N --startup-ms N --audio-ctx N --threads N --vad-threshold N [--no-gpu]\n  voice-control-runtime controls --port CLIENT[:PORT] --whisrs FILE --dotool FILE --gate FILE --command-note N --german-note N --enter-note N --dictation-note N --english Mod+A --german Mod+Shift+A --mouse-button 275 --german-mouse-button 276 [--disable-mouse]"
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
            no_gpu: args.iter().any(|arg| arg == "--no-gpu"),
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
            parse_value(&args, "--mouse-button")?,
            parse_value(&args, "--german-mouse-button")?,
            !args.iter().any(|arg| arg == "--disable-mouse"),
        ),
        _ => usage(),
    }
}

#[cfg(test)]
mod tests {
    use super::{
        KEY_COUNT, Transform, TransformAction, keyboard_output_blocked, matches_shortcut,
        normalize_process_name, replacement_actions, selected_text, shortcut_keys,
    };
    use regex::Regex;
    use serde_json::json;

    #[test]
    #[ignore = "requires evaluated configuration; run ../test-transforms.sh"]
    fn configured_dictation_preserves_prose_and_corrects_terminal_commands() {
        let path = std::env::var_os("VOICE_CONTROL_TEST_CONFIG")
            .expect("run modules/voice-control/test-transforms.sh");
        let config = super::RuntimeConfig::load(std::path::Path::new(&path)).unwrap();
        let mut snapshot = super::Snapshot {
            focused: super::FocusedWindow {
                raw: serde_json::Value::Null,
                app_id: Some("kitty".into()),
                title: None,
                pid: None,
            },
            interactive_layers: vec![],
            interactive_layer_names: vec![],
            overview: false,
            processes: vec![],
        };
        let helix_commands = config
            .command_modes
            .iter()
            .find(|mode| mode.name == "helix")
            .unwrap();
        for (aliases, expected) in [
            (
                &[
                    "goto",
                    "go to",
                    "go-to",
                    "go too",
                    "go two",
                    "go to definition",
                    "definition",
                ][..],
                "key esc; key g; key d",
            ),
            (
                &[
                    "back",
                    "beck",
                    "backward",
                    "backwards",
                    "go back",
                    "jump back",
                ][..],
                "key esc; key ctrl+o",
            ),
            (
                &[
                    "into",
                    "in to",
                    "in-to",
                    "forward",
                    "forwards",
                    "go forward",
                    "jump forward",
                ][..],
                "key esc; key ctrl+i",
            ),
            (
                &["up", "half page up", "half-page up", "page up"][..],
                "key esc; key ctrl+u",
            ),
            (
                &["down", "half page down", "half-page down", "page down"][..],
                "key esc; key ctrl+d",
            ),
        ] {
            for alias in aliases {
                assert_eq!(
                    helix_commands.commands.get(*alias).map(String::as_str),
                    Some(expected)
                );
                for segment in super::split_action_segments(expected).unwrap() {
                    assert_eq!(super::split_words(&segment).unwrap()[0], "key");
                }
            }
        }
        for (process, matches) in [
            ("hx", true),
            ("helix", true),
            ("fish", false),
            ("codex", false),
        ] {
            snapshot.processes = vec![super::ProcessInfo {
                name: process.into(),
                foreground: true,
            }];
            assert_eq!(helix_commands.matcher.matches(&snapshot), matches);
        }
        snapshot.processes.clear();
        let check = |snapshot: &super::Snapshot,
                     input: &str,
                     expected: &str,
                     partial: &str,
                     german: &str| {
            for language in ["de", "en"] {
                for whole_session in [true, false] {
                    let body = serde_json::to_vec(&json!({
                        "messages": [{"role": "user", "content": format!(
                            "Selected text:\n{input}\n\nInstruction: dictate"
                        )}],
                        "dictation": {"wholeSession": whole_session, "language": language}
                    }))
                    .unwrap();
                    let result = super::apply_transform(&config, snapshot, &body).unwrap();
                    if let Some(result) = &result {
                        assert!(
                            !result.submit,
                            "shell correction must not execute {input:?}"
                        );
                        assert!(result.actions_before.is_empty());
                    }
                    assert_eq!(
                        result.map(|r| r.output).as_deref().unwrap_or(input),
                        if !whole_session {
                            partial
                        } else if language == "de" {
                            german
                        } else {
                            expected
                        },
                        "input={input:?}, language={language}, whole_session={whole_session}"
                    );
                }
            }
        };
        for (input, expected) in [
            ("Commit.", "git commit"),
            ("Git commit git commit.", "git commit"),
            ("Commit, git commit! Commit.", "git commit"),
            ("Get kommit.", "git commit"),
            ("Git come with me.", "git commit"),
            ("Get this.", "git diff"),
            ("skid", "git"),
            ("SKIT.", "git"),
            ("skid diff", "git diff"),
            ("Skit status.", "git status"),
            ("skid. push origin MyBranch", "git push origin MyBranch"),
            ("skit diff--compact summary", "git diff --compact-summary"),
            ("skid diff -- src/MyFile.rs", "git diff -- src/MyFile.rs"),
            ("s.s.h. host", "ssh host"),
            ("s.s.h.host", "ssh host"),
            ("s.s.h. -p 2222 User@MyHost", "ssh -p 2222 User@MyHost"),
            ("s. s. h. User@MyHost", "ssh User@MyHost"),
            ("skip status", "git status"),
            ("Skip status.", "git status"),
            ("skip. status", "git status"),
            ("skip status, --short", "git status --short"),
            ("skip status--short", "git status --short"),
            (
                "skip status -- src/MyFile.rs",
                "git status -- src/MyFile.rs",
            ),
            ("kid push", "git push"),
            ("Kid push.", "git push"),
            ("kid. push origin MyBranch", "git push origin MyBranch"),
            ("kid push--force with lease", "git push --force-with-lease"),
            ("good. def", "git diff"),
            ("kids. diff", "git diff"),
            ("kidz def", "git diff"),
            ("good. tiff", "git diff"),
            ("good dev", "git diff"),
            ("git div", "git diff"),
            ("git different", "git diff"),
            ("GIT DIFFERENT.", "git diff"),
            ("git.different,--stat", "git diff --stat"),
            (
                "git different--compact summary",
                "git diff --compact-summary",
            ),
            (
                "git different -- src/MyFile.rs",
                "git diff -- src/MyFile.rs",
            ),
            ("git the different", "git diff"),
            ("git a diff", "git diff"),
            ("git a pull", "git pull"),
            ("git to push", "git push"),
            ("GIT TO PUSH.", "git push"),
            ("git to push origin MyBranch", "git push origin MyBranch"),
            (
                "git to push--force with lease",
                "git push --force-with-lease",
            ),
            ("git to,push", "git push"),
            (
                "git to push,--force with lease",
                "git push --force-with-lease",
            ),
            ("get to pushed origin MyBranch", "git push origin MyBranch"),
            ("git to push git push", "git push"),
            ("git the pull", "git pull"),
            ("GIT THE PULL.", "git pull"),
            ("git the pull origin MyBranch", "git pull origin MyBranch"),
            ("git the pull--rebase", "git pull --rebase"),
            ("git the,pull", "git pull"),
            ("git the pull,--rebase", "git pull --rebase"),
            ("get the pull origin MyBranch", "git pull origin MyBranch"),
            ("GIT A PULL.", "git pull"),
            ("git a pull origin MyBranch", "git pull origin MyBranch"),
            ("git a pull--rebase", "git pull --rebase"),
            ("git a,pull", "git pull"),
            ("git a pull,--rebase", "git pull --rebase"),
            ("kids. a pull origin MyBranch", "git pull origin MyBranch"),
            ("git a pull git pull", "git pull"),
            ("git the diff", "git diff"),
            ("git the,diff", "git diff"),
            ("git the.diff", "git diff"),
            ("git the diff,--stat", "git diff --stat"),
            ("Git. the, diff. --stat", "git diff --stat"),
            ("git there", "git diff"),
            ("GIT THERE.", "git diff"),
            ("git there--compact summary", "git diff --compact-summary"),
            ("git there -- src/MyFile.rs", "git diff -- src/MyFile.rs"),
            ("git the fuck out of here", "git diff"),
            ("Git the fuck out of here!", "git diff"),
            ("git that div", "git diff"),
            ("git to diff", "git diff"),
            ("GIT THE DIFF.", "git diff"),
            ("kids. a diff", "git diff"),
            (
                "git the diff--compact summary",
                "git diff --compact-summary",
            ),
            ("git that div, --name only", "git diff --name-only"),
            ("git to diff -- src/MyFile.rs", "git diff -- src/MyFile.rs"),
            ("git a. diff --stat", "git diff --stat"),
            ("git a diff git the diff", "git diff"),
            ("GIT DIV.", "git diff"),
            ("kids. div, --name only", "git diff --name-only"),
            ("git div--compact summary", "git diff --compact-summary"),
            ("git div -- src/MyFile.rs", "git diff -- src/MyFile.rs"),
            ("DROICS dash dash help", "droix --help"),
            (
                "DROIC'S run --project ./MyProject",
                "droix run --project ./MyProject",
            ),
            ("Git logger", "git log"),
            ("Git logger.", "git log"),
            ("GIT LOGGER", "git log"),
            ("kids. logger", "git log"),
            ("git logger, --oneline", "git log --oneline"),
            ("git logger--oneline", "git log --oneline"),
            ("git logger -- src/MyFile.rs", "git log -- src/MyFile.rs"),
            ("git longer", "git log"),
            ("Git longer.", "git log"),
            ("git longer, --oneline", "git log --oneline"),
            ("git longer--oneline", "git log --oneline"),
            ("git longer -- src/MyFile.rs", "git log -- src/MyFile.rs"),
            ("good luck", "git log"),
            ("Good luck.", "git log"),
            ("GOOD LUCK", "git log"),
            ("good. luck, --oneline", "git log --oneline"),
            ("good luck--oneline", "git log --oneline"),
            ("good luck -- src/MyFile.rs", "git log -- src/MyFile.rs"),
            ("KIDZ. DEF.", "git diff"),
            ("kids,def", "git diff"),
            ("good.def", "git diff"),
            ("kids def, --name only", "git diff --name-only"),
            ("kidz. tiff--compact summary", "git diff --compact-summary"),
            ("good dev -- src/MyFile.rs", "git diff -- src/MyFile.rs"),
            ("git diff--compact summary", "git diff --compact-summary"),
            (
                "git diff double dash compact dash summary",
                "git diff --compact-summary",
            ),
            ("git diff --compact, summary", "git diff --compact-summary"),
            ("GIT DIFF--COMPACT SUMMARY", "git diff --compact-summary"),
            ("get diff--name status", "git diff --name-status"),
            (
                "git diff double dash compact summary",
                "git diff --compact-summary",
            ),
            (
                "git diff --ignore all space --name only",
                "git diff --ignore-all-space --name-only",
            ),
            (
                "git diff --find copies harder",
                "git diff --find-copies-harder",
            ),
            (
                "git diff --word diff regex=MyPattern",
                "git diff --word-diff-regex=MyPattern",
            ),
            ("git push--force with lease", "git push --force-with-lease"),
            (
                "git push --set upstream origin MyBranch",
                "git push --set-upstream origin MyBranch",
            ),
            ("git commit --no verify", "git commit --no-verify"),
            ("git c --amend.", "git c --amend"),
            ("git c --amend...", "git c --amend"),
            (
                "git commit --amend --no edit.",
                "git commit --amend --no-edit",
            ),
            ("git diff--compact summary.", "git diff --compact-summary"),
            ("git add .", "git add ."),
            ("git diff -- ./file.", "git diff -- ./file."),
            (
                "git commit -m \"Keep this period.\"",
                "git commit -m \"Keep this period.\"",
            ),
            ("git diff file dot", "git diff file."),
            ("git status--short", "git status --short"),
            ("git diff --unknown option", "git diff --unknown option"),
            (
                "git diff -- --compact summary",
                "git diff -- --compact summary",
            ),
            (
                "git commit -m \"Keep --compact summary literal\"",
                "git commit -m \"Keep --compact summary literal\"",
            ),
            (
                "git log --format=\"Keep --name status\"",
                "git log --format=\"Keep --name status\"",
            ),
            ("get the", "git diff"),
            ("Get the.", "git diff"),
            ("GET THE", "git diff"),
            ("get and", "git add"),
            ("get pushed", "git push"),
            ("get the push", "git push"),
            ("Get the push.", "git push"),
            ("GET THE PUSH", "git push"),
            ("get the pushed", "git push"),
            ("get the push origin main", "git push origin main"),
            (
                "get the push --force with lease",
                "git push --force-with-lease",
            ),
            ("Get pushed.", "git push"),
            ("GET PUSHED", "git push"),
            ("get pushed origin main", "git push origin main"),
            ("Get, pushed origin main", "git push origin main"),
            (
                "get pushed --force with lease",
                "git push --force-with-lease",
            ),
            ("get", "git"),
            ("Get.", "git"),
            ("get custom-alias", "git custom-alias"),
            ("getting", "getting"),
            ("please get something", "please get something"),
            ("Get and.", "git add"),
            ("GET AND", "git add"),
            ("get and dot", "git add ."),
            ("get and src/main.rs", "git add src/main.rs"),
            (
                "Get the clone https://example.com/Repo",
                "git clone https://example.com/Repo",
            ),
            ("Good started!", "git status"),
            ("Good to see you.", "git c"),
            ("Git check out.", "git checkout"),
            ("Git cherry pick.", "git cherry-pick"),
            (
                "GIT COMMIT -m \"Fix German Nouns.\"",
                "git commit -m \"Fix German Nouns.\"",
            ),
            (
                "Commit git commit -m \"Commit commit\"",
                "git commit -m \"Commit commit\"",
            ),
            ("Git C-a", "git c -a"),
            ("Git c dash a.", "git c -a"),
            ("Git add Punkt.", "git add ."),
            (
                "Git commit minus m \"Fix Casing\"",
                "git commit -m \"Fix Casing\"",
            ),
            ("Nicks Build.", "nix build"),
            ("Nyx flake update.", "nix flake update"),
            ("nix Flake Update LLM-Agents", "nix flake update llm-agents"),
            (
                "NIX FLAKE UPDATE LLM-AGENTS.",
                "nix flake update llm-agents",
            ),
            ("nix.Flake.Update LLM-Agents", "nix flake update llm-agents"),
            ("Next fake Update LLM-Agents", "nix flake update llm-agents"),
            (
                "nix Flake Update LLM-Agents NIXPKGS",
                "nix flake update llm-agents nixpkgs",
            ),
            (
                "nix Flake Update NIXPKGS LLM-Agents",
                "nix flake update nixpkgs llm-agents",
            ),
            ("nix Flake Update MyInput", "nix flake update MyInput"),
            (
                "nix Flake Check ./MyProject --keep-going",
                "nix flake check ./MyProject --keep-going",
            ),
            ("nix Flake Show ./MyProject", "nix flake show ./MyProject"),
            (
                "nix Flake Lock --override-input Example github:Org/Repo",
                "nix flake lock --override-input Example github:Org/Repo",
            ),
            (
                "nix Flake Update LLM-Agents --flake ./MyProject",
                "nix flake update llm-agents --flake ./MyProject",
            ),
            (
                "nix Flake Update --flake LLM-Agents",
                "nix flake update --flake LLM-Agents",
            ),
            (
                "nix Flake Update \"LLM-Agents\"",
                "nix flake update \"LLM-Agents\"",
            ),
            ("nix, run", "nix run"),
            ("nix. run", "nix run"),
            ("nix.flake.update", "nix flake update"),
            ("git,diff", "git diff"),
            ("git. diff, --compact summary", "git diff --compact-summary"),
            ("Get. and, src/main.rs", "git add src/main.rs"),
            ("cargo. test", "cargo test"),
            (
                "cargo,test,--package my-crate",
                "cargo test --package my-crate",
            ),
            ("pnpm,run,dev", "pnpm run dev"),
            ("rg,needle", "rg needle"),
            ("hx. src/main.rs", "hx src/main.rs"),
            (
                "curl,https://example.com/a,b",
                "curl https://example.com/a,b",
            ),
            (
                "git.remote.add,origin https://example.com/repo.git",
                "git remote add origin https://example.com/repo.git",
            ),
            ("git diff test.file", "git diff test.file"),
            ("rg test.file", "rg test.file"),
            ("hx .config", "hx .config"),
            ("git add ./src", "git add ./src"),
            ("git diff -- file,a.rs", "git diff -- file,a.rs"),
            (
                "git commit -m \"One, two. Three.\"",
                "git commit -m \"One, two. Three.\"",
            ),
            ("Nix, run.", "nix run"),
            ("nix,run", "nix run"),
            ("nix, run .#app", "nix run .#app"),
            ("nix, build .#package", "nix build .#package"),
            ("nix, flake update", "nix flake update"),
            ("nixrun.hashtag app", "nix run .#app"),
            ("nixrun.hashtag, app", "nix run .#app"),
            ("nix run.hashtag app", "nix run .#app"),
            ("nixrun . hashtag app", "nix run .#app"),
            ("nix run dot hashtag app", "nix run .#app"),
            ("nixbuild.hashtag package", "nix build .#package"),
            ("nixdevelop.#dev", "nix develop .#dev"),
            ("nix run .#app", "nix run .#app"),
            ("Kargo Check.", "cargo check"),
            ("Cargo Add serde", "cargo add serde"),
            ("PNPM Run test", "pnpm run test"),
            (
                "Cargo Test --package MyCrate",
                "cargo test --package MyCrate",
            ),
            ("H ex.", "hx"),
            ("Felix.", "hx"),
            ("hey, lex", "hx"),
            ("Hey, Lex.", "hx"),
            ("hey-lex", "hx"),
            ("hey,lex src/main.rs", "hx src/main.rs"),
            ("FELIX", "hx"),
            ("felix src/main.rs", "hx src/main.rs"),
            ("felix slash tmp slash file dot rs", "hx /tmp/file.rs"),
            ("Ha iks.", "hx"),
            ("En vau top.", "nvtop"),
            ("Er ge.", "rg"),
            ("Ef de.", "fd"),
            ("System C T L.", "systemctl"),
            ("John city hall.", "journalctl"),
            ("Z dot.", "z dot"),
            ("Z", "z"),
            ("Z.", "z"),
            ("ZEE", "z"),
            ("the", "z"),
            ("The.", "z"),
            ("THE", "z"),
            ("the MyProject", "z myproject"),
            ("The My Project Source Code.", "z my project source code"),
            ("the, MyProject!", "z myproject"),
            ("the ./MyProject/Src", "z ./myproject/src"),
            ("the My minus Project slash Src", "z my-project/src"),
            ("the dot", "z dot"),
            ("the draw x", "z droix"),
            ("the-droix", "z droix"),
            ("Z MyProject", "z myproject"),
            ("Z My Project Source Code.", "z my project source code"),
            ("Z ./MyProject/Src", "z ./myproject/src"),
            ("Z~/Documents/MyProject", "z ~/documents/myproject"),
            ("Z/Projects/MyProject", "z /projects/myproject"),
            ("Z My.Project.", "z my.project"),
            ("Z My dash Project", "z my-project"),
            ("Z My minus Project slash Src", "z my-project/src"),
            ("Z slash Home slash Projects", "z /home/projects"),
            ("Z, MyProject!", "z myproject"),
            ("C MyProject", "z myproject"),
            ("z-droix", "z droix"),
            ("zdrawx", "z droix"),
            ("c droix", "z droix"),
            ("C Droix.", "z droix"),
            ("zDroix", "z droix"),
            ("zDrawX.", "z droix"),
            ("zDROICS", "z droix"),
            ("zDROIC'S", "z droix"),
            ("cDroi’cs", "z droix"),
            ("c draw x", "z droix"),
            ("c-drawX", "z droix"),
            ("z - droix", "z droix"),
            ("z, draw x.", "z droix"),
            ("zee dash droix", "z droix"),
            ("z minus draw x", "z droix"),
            ("c droix c droix", "z droix"),
            ("c project", "z project"),
            ("z - project", "z project"),
            ("zm/", "z m/"),
            ("ZM/", "z m/"),
            ("zMyProject/Src", "z myproject/src"),
            ("zeditor", "z editor"),
            ("Satura", "zathura"),
            ("SATURA.", "zathura"),
            ("satura", "zathura"),
            ("Zathura.", "zathura"),
            ("zatura", "zathura"),
            ("Sathura", "zathura"),
            ("satura document.pdf", "zathura document.pdf"),
            ("zathura dash dash help", "zathura --help"),
            ("zathuraproject", "z athuraproject"),
            ("zebra", "z ebra"),
            ("zdrawxadapter", "z drawxadapter"),
        ] {
            check(&snapshot, input, expected, expected, expected);
        }
        for (expected, aliases) in [
            (
                "droix",
                vec![
                    "strokes", "strikes", "Strokes.", "Strikes.", "draw x", "DrawX",
                ],
            ),
            (
                "rg",
                vec![
                    "R.D.", "R-G-R-G.", "R.G.", "RG", "Rd", "R-G", "Rg", "Lip gap.", "Ripgrab.",
                    "Ripgrap.", "Ripgrep.",
                ],
            ),
            ("ll", vec!["List.", "And ass.", "LS", "L.S.", "list"]),
            (
                "nixpkgs",
                vec![
                    "Nick's PKG's",
                    "Next PKGs.",
                    "Nick's Picky G's.",
                    "NixPKGs.",
                    "Next pick I guess.",
                    "Nick's Pick A Gaze.",
                    "Nix pick I guess.",
                    "No PKGs.",
                    "Nick's Pekka Gays.",
                    "Next pick, I guess.",
                    "Nix PKGs.",
                    "Nick's Baker, I guess.",
                    "xpkgs",
                    "Nix P.K.G.'s.",
                    "Nick's pick, I guess.",
                    "next pick a kiss",
                    "Mixed PKGs.",
                ],
            ),
            (
                "cargo",
                vec!["Cargo.", "Kind of.", "Car golf.", "Cargolf.", "Caggle."],
            ),
            (
                "nix flake update",
                vec![
                    "Nix Flake Update.",
                    "Next flake update.",
                    "Flake update.",
                    "FlixFlake Update.",
                    "next fake update.",
                    "Mix Flake Update.",
                ],
            ),
            ("codex", vec!["Codex.", "Cool, Diggs."]),
            (
                "ssh",
                vec![
                    "SSH.", "s.s.h.", "S.S.H.", "s. s. h.", "s s h", "s-s-h", "as aged", "Mrs. H.",
                    "it's H",
                ],
            ),
            (
                "htop",
                vec![
                    "It stopped.",
                    "H-top.",
                    "It's top.",
                    "Age top.",
                    "Each top five.",
                    "each top",
                    "It's tough.",
                    "age tops",
                    "H top.",
                ],
            ),
            ("fd", vec!["find", "Fine.", "find it.", "FD."]),
            (
                "git clone",
                vec![
                    "Get cloned.",
                    "git clone",
                    "Good club.",
                    "Get the clone.",
                    "Good, clear.",
                ],
            ),
        ] {
            for input in aliases {
                check(&snapshot, input, expected, expected, expected);
            }
        }
        for (input, expected) in [
            ("rg dash e double dash something", "rg -e --something"),
            ("rg, dash, e, dash, dash, something", "rg -e --something"),
            ("ripgrep dash e needle", "rg -e needle"),
            ("cargo test minus p my-crate", "cargo test -p my-crate"),
            ("npm run test dash dash watch", "npm run test --watch"),
            ("something, slash, blub", "something/blub"),
            ("some dash kebab minus case", "some-kebab-case"),
            ("rg slash tmp slash source", "rg /tmp/source"),
            (
                "git clone git@example.com slash repo",
                "git clone git@example.com/repo",
            ),
            (
                "git commit -m \"Keep dash and slash literal\"",
                "git commit -m \"Keep dash and slash literal\"",
            ),
        ] {
            check(&snapshot, input, expected, expected, expected);
        }
        check(
            &snapshot,
            "H X ./MyFile.rs",
            "hx ./myfile.rs",
            "hx ./MyFile.rs",
            "hx ./MyFile.rs",
        );
        check(
            &snapshot,
            "Zett Documents.",
            "z documents",
            "z documents",
            "z documents",
        );
        snapshot.focused.app_id = Some("org.example.Editor".into());
        for (input, expected) in [
            ("some dash kebab minus case", "some-kebab-case"),
            ("something, slash, blub", "something/blub"),
            ("some Slash folder Dash name", "some/folder-name"),
        ] {
            check(&snapshot, input, expected, expected, expected);
        }

        for (input, expected) in [
            ("Morgen.", "morgen"),
            ("Guten Morgen.", "guten morgen"),
            ("Das Ist Schön...", "das ist schön"),
            ("Good Morning Everyone.", "good morning everyone"),
            ("  Drei Kleine Wörter...  ", "drei kleine wörter"),
            ("Ist das gut?", "ist das gut?"),
            ("Heute ist schönes Wetter.", "Heute ist schönes Wetter."),
            ("Please show the changes.", "Please show the changes."),
        ] {
            check(
                &snapshot,
                input,
                expected,
                input,
                if input.split_whitespace().count() <= 3 {
                    input.trim().trim_end_matches('.')
                } else {
                    input
                },
            );
        }
        // Recognition aliases only affect the command prefix, including in a terminal.
        snapshot.focused.app_id = Some("kitty".into());
        for input in [
            "I said good. def earlier.",
            "Please explain kids. diff to me.",
            "These words kidz def belong here.",
            "That sounds like good. tiff today.",
            "We need a good dev today.",
            "Kids play outside every day.",
            "Good development takes some time.",
            "Please explain Git logger to me.",
            "Please explain git longer to me.",
            "I wish you good luck today.",
            "Please explain kid push to me.",
            "Please explain git div to me.",
            "I said git different earlier.",
            "I said git a pull earlier.",
            "I said git to push earlier.",
            "git to pushback",
            "git show --format=\"git to push\"",
            "git diff -- to push",
            "I said git the pull earlier.",
            "git the pullover",
            "git a pullover",
            "git show --format=\"git a pull\"",
            "git diff -- a pull",
            "git differently",
            "git diff -- different",
            "git show --format=\"git different\"",
            "Please explain git a diff to me.",
            "I said git the diff earlier.",
            "I said git there earlier.",
            "I said git the fuck out of here earlier.",
            "git thereafter",
            "git diff -- there",
            "git show --format=\"git the fuck out of here\"",
            "git the fuck out of here please",
            "Please explain git that div to me.",
            "I said git to diff earlier.",
            "git that division",
            "git diff -- that div",
            "git show --format=\"git a diff\"",
            "git log -- div",
            "git diverse",
            "Please skip status checks for now.",
            "Please explain nix Flake Update LLM-Agents to me.",
            "Please explain skid diff to me.",
            "We discussed skit status earlier.",
            "skidding across the road",
            "git log -- skid skit",
            "Please use s.s.h. to connect.",
            "cat s.s.h.config",
            "rg --fixed-strings \"s.s.h.\" src/MyFile.rs",
            "sshd",
            "s.s.html",
            "skip testing for now",
            "skipping status checks",
            "git log -- skip status",
            "I watched the kid push the door.",
            "I said the directory name earlier.",
            "Theater opens its doors today.",
            "theory",
            "rg \"the MyProject\" src/MyFile.rs",
            "kid pushes the door",
            "git log -- kid push",
            "git longername",
            "git loggers",
            "git log -- logger",
            "git log -- longer luck",
            "git diff -- good.def kids.diff",
            "git log --grep=\"good dev\" --all",
            "rg \"kids. diff\" src/MyFile.rs",
        ] {
            check(&snapshot, input, input, input, input);
        }
        for head in [
            "git", "get", "kit", "good", "did", "gitt", "kid", "kids", "kidz", "skip", "skid",
            "skit",
        ] {
            for subcommand in [
                "status", "add", "log", "show", "fetch", "pull", "push", "branch", "switch",
                "checkout", "merge", "rebase", "stash", "restore", "reset", "clone",
            ] {
                for separator in [" ", ". ", ","] {
                    let input = format!("{head}{separator}{subcommand}");
                    let expected = format!("git {subcommand}");
                    check(&snapshot, &input, &expected, &expected, &expected);
                }
            }
        }
        // A pause must not make the middle of a recording into a command head.
        for (input, corrected, later) in [
            ("good. def", "git diff", "good. def"),
            ("kids. diff", "git diff", "kids. diff"),
            ("kidz def", "git diff", "kidz def"),
            ("good. tiff", "git diff", "good. tiff"),
            ("good dev", "git diff", "good dev"),
            ("git div", "git diff", "git div"),
            ("git different", "git diff", "git different"),
            ("git a diff", "git diff", "git a diff"),
            ("git a pull", "git pull", "git a pull"),
            ("git to push", "git push", "git to push"),
            ("git the pull", "git pull", "git the pull"),
            ("git the diff", "git diff", "git the diff"),
            ("git there", "git diff", "git there"),
            (
                "git the fuck out of here",
                "git diff",
                "git the fuck out of here",
            ),
            ("git that div", "git diff", "git that div"),
            ("git to diff", "git diff", "git to diff"),
            ("DROICS", "droix", "droix"),
            ("get pushed", "git push", "get pushed"),
            ("Git logger", "git log", "Git logger"),
            ("git longer", "git log", "git longer"),
            ("good luck", "git log", "good luck"),
            ("kid push", "git push", "kid push"),
            ("skip status", "git status", "skip status"),
            ("skid", "git", "skid"),
            ("skit status", "git status", "skit status"),
            ("s.s.h.", "ssh", "s.s.h."),
            ("s.s.h. host", "ssh host", "s.s.h. host"),
            ("The MyProject", "z myproject", "The MyProject"),
            ("the", "z", "the"),
            ("car golf test", "cargo test", "car golf test"),
            ("next flake update", "nix flake update", "next flake update"),
            (
                "nix Flake Update LLM-Agents",
                "nix flake update llm-agents",
                "nix Flake Update LLM-Agents",
            ),
            ("fine src", "fd src", "fine src"),
            ("hey lex file.rs", "hx file.rs", "hey lex file.rs"),
            ("drawX", "droix", "droix"),
            ("file dot rs", "file.rs", "file.rs"),
            ("label colon value", "label: value", "label: value"),
            ("snake underscore case", "snake_case", "snake_case"),
        ] {
            for language in ["en", "de"] {
                for session_start in [true, false] {
                    let body = serde_json::to_vec(&json!({
                        "messages": [{"role": "user", "content": format!(
                            "Selected text:\n{input}\n\nInstruction: dictate"
                        )}],
                        "dictation": {"wholeSession": false, "sessionStart": session_start, "language": language}
                    })).unwrap();
                    let result = super::apply_transform(&config, &snapshot, &body).unwrap();
                    assert_eq!(
                        result.map(|r| r.output).as_deref().unwrap_or(input),
                        if session_start { corrected } else { later },
                        "input={input:?}, language={language}, session_start={session_start}"
                    );
                }
            }
        }
        let prose = [
            "Heute ist schönes Wetter.",
            "Please show the changes.",
            "Get the latest version.",
            "Git commit ist der richtige Befehl.",
            "Commit to the plan.",
            "Das ist sehr sehr gut.",
            "I said git commit git commit twice.",
        ];
        for app in ["firefox", "org.example.Editor"] {
            snapshot.focused.app_id = Some(app.into());
            for input in prose {
                check(&snapshot, input, input, input, input);
            }
        }
        for (app, process) in [
            ("kitty", "fish"),
            ("firefox", "firefox"),
            ("kitty", "codex"),
            ("kitty", "hx"),
        ] {
            snapshot.focused.app_id = Some(app.into());
            snapshot.processes = vec![super::ProcessInfo {
                name: process.into(),
                foreground: true,
            }];
            for (input, expected) in [
                ("underscore", "_"),
                ("UNDERSCORE.", "_"),
                ("under score", "_"),
                ("snake underscore case", "snake_case"),
                ("snake under score case", "snake_case"),
                ("snake under-score case", "snake_case"),
                ("snake, underscore, case", "snake_case"),
                ("snake underscore underscore case", "snake__case"),
                ("underscore name", "_name"),
                ("name underscore", "name_"),
                ("file underscore name dot rs", "file_name.rs"),
                ("file underscore dot rs", "file_.rs"),
                ("dot underscore config", "._config"),
                ("file dot underscore name", "file._name"),
                ("\"snake underscore case\"", "\"snake_case\""),
                ("'snake underscore case'", "'snake_case'"),
                ("Use snake underscore case here.", "Use snake_case here."),
                ("snake_case", "snake_case"),
                ("underscores", "underscores"),
                ("dot", "."),
                ("dot.", "."),
                ("dot dot", ".."),
                ("file dot rs", "file.rs"),
                ("file, dot, ts", "file.ts"),
                ("label colon value", "label: value"),
                ("hashtag", "#"),
                ("HASHTAG", "#"),
                ("hash tag", "#"),
                ("hashtag heading", "#heading"),
                ("\"hashtag\"", "\"#\""),
                (
                    "Put a hashtag before this heading",
                    "Put a #before this heading",
                ),
                ("hashtagged", "hashtagged"),
                ("label, colon, value", "label: value"),
                ("colon", ":"),
                (
                    "https colon slash slash example dot com",
                    "https://example.com",
                ),
                ("\"label colon value\"", "\"label: value\""),
                ("dot config", ".config"),
                ("dot slash src slash main dot rs", "./src/main.rs"),
                ("\"file dot ts\"", "\"file.ts\""),
                ("z dot", "z dot"),
                ("dotnet", "dotnet"),
            ] {
                check(&snapshot, input, expected, expected, expected);
            }
            check(
                &snapshot,
                "My underscore Name",
                "my_name",
                "My_Name",
                "My_Name",
            );
            if process == "fish" {
                for (input, expected) in [
                    ("rg underscore", "rg _"),
                    ("git diff foo underscore bar dot rs", "git diff foo_bar.rs"),
                    ("z My underscore Project", "z my_project"),
                    ("rg dot", "rg ."),
                    ("hx dot slash src slash main dot rs", "hx ./src/main.rs"),
                    ("git add dot", "git add ."),
                    ("zee dot", "z dot"),
                    ("c dot", "z dot"),
                    ("zdot", "z dot"),
                    ("Zdot.", "z dot"),
                    ("zDot", "z dot"),
                    ("ZDOT", "z dot"),
                    ("z-dot", "z dot"),
                    ("z_dot", "z dot"),
                    ("z dash dot", "z dot"),
                    ("zeeDot", "z dot"),
                    ("cdot", "z dot"),
                    ("zdot zdot", "z dot"),
                ] {
                    check(&snapshot, input, expected, expected, expected);
                }
            } else {
                check(&snapshot, "zdot", "zdot", "zdot", "zdot");
            }
            for input in [
                "draw x",
                "draw-x",
                "draw_x",
                "drawX",
                "DrawX",
                "DRAW X",
                "draw–X",
                "draw — x",
                "draw, X",
                "draw dash x",
                "draw minus x",
                "droics",
                "DROICS",
                "DroiCs",
                "DROIC'S",
                "DROIC’S",
                "DROIC‘S",
                "Droi'cs",
                "dro'ics",
                "d'roics",
                "d'r'o'i'c's",
                "DROIX",
                "DROI'X",
            ] {
                check(&snapshot, input, "droix", "droix", "droix");
            }
            for (input, expected) in [
                ("Please open DROICS for me.", "Please open droix for me."),
                (
                    "Ich arbeite mit Droic’s heute.",
                    "Ich arbeite mit droix heute.",
                ),
                (
                    "Use DROICS and Droi'cs together.",
                    "Use droix and droix together.",
                ),
                ("\"DROICS\"", "\"droix\""),
                ("'DROICS'", "'droix'"),
                (
                    "Please check DROICS's configuration today.",
                    "Please check droix's configuration today.",
                ),
                (
                    "Keep droicsAdapter and redroics unchanged.",
                    "Keep droicsAdapter and redroics unchanged.",
                ),
                ("Please open drawX for me.", "Please open droix for me."),
                (
                    "Ich arbeite mit Draw-X heute.",
                    "Ich arbeite mit droix heute.",
                ),
                (
                    "Use draw x and DrawX together.",
                    "Use droix and droix together.",
                ),
                (
                    "Keep drawXAdapter and redrawX unchanged.",
                    "Keep drawXAdapter and redrawX unchanged.",
                ),
            ] {
                check(&snapshot, input, expected, expected, expected);
            }
            if process == "fish" {
                check(
                    &snapshot,
                    "strikes dash dash help",
                    "droix --help",
                    "droix --help",
                    "droix --help",
                );
            } else {
                for input in [
                    "z-droix",
                    "zdrawx",
                    "c droix",
                    "Z My Project Source Code.",
                    "the myproject",
                    "the",
                ] {
                    check(&snapshot, input, input, input, input);
                }
                check(&snapshot, "strikes", "strikes", "strikes", "strikes");
                check(&snapshot, "felix", "felix", "felix", "felix");
                for input in [
                    "git,diff",
                    "cargo. test",
                    "nix. run",
                    "good. def",
                    "kids. diff",
                    "kidz def",
                    "good. tiff",
                    "good dev",
                    "git div",
                    "git different",
                    "git a diff",
                    "git a pull",
                    "git to push",
                    "git the pull",
                    "git the diff",
                    "git there",
                    "git the fuck out of here",
                    "git that div",
                    "git to diff",
                    "git logger",
                    "kid push",
                    "skip status",
                    "nix Flake Update LLM-Agents",
                    "skid",
                    "skit diff",
                    "s.s.h. host",
                    "git longer",
                    "good luck",
                ] {
                    check(&snapshot, input, input, input, input);
                }
                check(
                    &snapshot,
                    "get pushed",
                    "get pushed",
                    "get pushed",
                    "get pushed",
                );
                check(
                    &snapshot,
                    "get custom-alias",
                    "get custom-alias",
                    "get custom-alias",
                    "get custom-alias",
                );
                check(
                    &snapshot,
                    "git diff--compact summary",
                    "git diff--compact summary",
                    "git diff--compact summary",
                    "git diff--compact summary",
                );
                for input in ["zm/", "satura", "zebra", "zathura"] {
                    check(&snapshot, input, input, input, input);
                }
                check(&snapshot, "strokes", "strokes", "strokes", "strokes");
                let sentence = "She draws strokes and strikes lines.";
                check(&snapshot, sentence, sentence, sentence, sentence);
            }
        }
        // A command phrase is prose outside the terminal, including Codex/Helix
        // hosted inside a terminal (their higher-priority modes take precedence).
        for (app, process) in [("firefox", "firefox"), ("kitty", "codex"), ("kitty", "hx")] {
            snapshot.focused.app_id = Some(app.into());
            snapshot.processes = vec![super::ProcessInfo {
                name: process.into(),
                foreground: true,
            }];
            check(&snapshot, "Commit.", "commit", "Commit.", "Commit");
            check(
                &snapshot,
                "Git commit git commit.",
                "Git commit git commit.",
                "Git commit git commit.",
                "Git commit git commit.",
            );
        }
    }

    #[test]
    fn output_waits_for_letter_and_all_modifiers_to_release() {
        for keys in [vec![30, 125], vec![125], vec![30], vec![42], vec![126, 54]] {
            let mut held = [false; KEY_COUNT];
            for key in keys {
                held[key] = true;
            }
            assert!(keyboard_output_blocked(&held, &[30, 30]));
        }
        let mut held = [false; KEY_COUNT];
        assert!(!keyboard_output_blocked(&held, &[30, 30]));
        held[48] = true;
        assert!(!keyboard_output_blocked(&held, &[30, 30]));
        assert!(keyboard_output_blocked(&held, &[30, 48]));
    }

    #[test]
    fn mouse_dictation_streams_while_either_button_is_held() {
        let mut held = [false; KEY_COUNT];
        for button in [275, 276] {
            held[button] = true;
            assert!(matches_shortcut(&held, button, &[]));
            assert!(!keyboard_output_blocked(&held, &[30, 30]));
            held[button] = false;
            assert!(!matches_shortcut(&held, button, &[]));
        }
    }

    #[test]
    fn discovers_live_niri_socket_and_rejects_ambiguous_sessions() {
        let dir = std::env::temp_dir().join(format!("voice-niri-test-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let first = dir.join("niri.wayland-1.123.sock");
        let second = dir.join("niri.wayland-2.456.sock");
        let listener = std::os::unix::net::UnixListener::bind(&first).unwrap();
        let (_, socket) = super::discover_niri_stream(&dir).unwrap();
        assert_eq!(socket, first);
        let other = std::os::unix::net::UnixListener::bind(&second).unwrap();
        assert!(super::discover_niri_stream(&dir).is_err());
        drop(other);
        assert!(super::discover_niri_stream(&dir).is_ok());
        drop(listener);
        assert!(super::discover_niri_stream(&dir).is_err());
        std::fs::remove_dir_all(dir).unwrap();
    }

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
        let mut held = [false; KEY_COUNT];
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
            whole_session_only: false,
            session_start_only: false,
            exclude_pattern: None,
            exclude_languages: vec![],
            spoken_punctuation: String::new(),
            after_modes: false,
            lowercase_first: false,
            lowercase_first_whole_session: false,
            german_max_words: None,
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
            whole_session_only: false,
            session_start_only: false,
            exclude_pattern: None,
            exclude_languages: vec![],
            spoken_punctuation: String::new(),
            after_modes: false,
            lowercase_first: false,
            lowercase_first_whole_session: false,
            german_max_words: None,
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
            whole_session_only: false,
            session_start_only: false,
            exclude_pattern: None,
            exclude_languages: vec![],
            spoken_punctuation: String::new(),
            after_modes: false,
            lowercase_first: false,
            lowercase_first_whole_session: false,
            german_max_words: None,
            trim_end_punctuation: false,
        };

        assert_eq!(
            transform.apply("find StructName"),
            Some(r"\k{esc}/StructName".to_owned())
        );
        assert_eq!(transform.apply("please find StructName"), None);
    }

    #[test]
    fn short_input_casing_requires_the_whole_recording_and_uses_language_limits() {
        let transform = Transform::compile(
            serde_json::from_value(json!({
                "name": "short-input", "pattern": r"(?s)^\s*(\S+(?:\s+\S+){0,3})\s*$",
                "replace": "$1", "lowercaseFirst": true, "lowercaseFirstWholeSession": true,
                "germanMaxWords": 2, "trimEndPunctuation": true
            }))
            .unwrap(),
        )
        .unwrap();
        let english = super::DictationSession {
            whole_session: true,
            session_start: true,
            language: "en".into(),
        };
        let german = super::DictationSession {
            whole_session: true,
            session_start: true,
            language: "de".into(),
        };
        let partial = super::DictationSession {
            whole_session: false,
            session_start: true,
            language: "de".into(),
        };

        assert_eq!(
            transform
                .apply_in_session("Guten Morgen.", Some(&german))
                .as_deref(),
            Some("guten Morgen")
        );
        assert_eq!(
            transform
                .apply_in_session("Heute ist schönes Wetter.", Some(&german))
                .as_deref(),
            Some("Heute ist schönes Wetter")
        );
        assert_eq!(
            transform
                .apply_in_session("Please show the changes.", Some(&english))
                .as_deref(),
            Some("please show the changes")
        );
        assert_eq!(
            transform
                .apply_in_session("Guten Morgen.", Some(&partial))
                .as_deref(),
            Some("Guten Morgen")
        );
        assert_eq!(
            transform
                .apply_in_session("Morgen.", Some(&partial))
                .as_deref(),
            Some("Morgen")
        );
        // Missing metadata must preserve casing rather than treating a fragment as a session.
        assert_eq!(
            transform.apply("Guten Morgen.").as_deref(),
            Some("Guten Morgen")
        );
        assert_eq!(
            transform.apply_in_session("This complete session has five words.", Some(&english)),
            None
        );
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
