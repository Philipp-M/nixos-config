let
  # An offline vocabulary: aliases are regexes, replacements have explicit casing.
  # Command heads and complete aliases match only in terminal mode. Repeated
  # aliases collapse to one command; arguments and quoted literals are retained.
  command = name: aliases: {
    inherit name;
    pattern = ''(?i)^\s*(?:${aliases})(?:[.!?,;]*\s+(?:${aliases}))*[.!?,]*\s*$'';
    replace = name;
  };
  # Terminal dictation is command-oriented: allow ordinary argument tails.
  # Keep that tail's casing and punctuation (paths and messages are case-sensitive).
  withArguments = name: aliases: {
    name = "${name}-arguments";
    pattern = ''(?i)^\s*(?:${aliases})(?:[.!?,;]*\s+(?:${aliases}))*[.,]?\s+([\s\S]+)$'';
    replace = "${name} $1";
  };
  gitHeads = ''(?:git|get|kit|good|did|gitt|kid|kids|kidz|skip|skid|skit)'';
  git = ''${gitHeads}[.,]?\s+'';
  nix = ''(?:nix|nick['’]?s|nicks|next|mix|nyx|nixs|nx)[,]?\s+'';
  cargo = ''(?:cargo|kargo|car\s+go|kind\s+of|car\s+golf|cargolf|caggle)\s+'';
  droixName = ''d['’‘]?r['’‘]?o['’‘]?i['’‘]?(?:c['’‘]?s|x)'';
  nixCommands = [
    "build" "develop" "shell" "run" "eval" "fmt" "log"
    "flake update" "flake check" "flake show" "flake lock"
  ];
  nixFlakeUpdate = ''(?:(?:${nix})?(?:flake|fake)\s+update|flix\s*flake\s+update)'';
  # Read only the declarations; importing this attrset never fetches its inputs.
  flakeInputs = builtins.attrNames (import ../../flake.nix).inputs;
  knownFlakeInput = builtins.concatStringsSep "|" flakeInputs;
  gitCommands = [
    "diff" "status" "c" "commit" "add" "log" "show" "fetch" "pull" "push"
    "branch" "switch" "checkout" "merge" "rebase" "stash" "restore" "reset"
    "cherry-pick" "clone" "remote" "tag" "bisect" "worktree" "submodule"
    "lfs" "pushall" "diffd" "difff"
  ];
  gitAlias = subcommand:
    if subcommand == "commit" then ''(?:${git}(?:commit|kommit|komit|com\s+mit|come\s+with\s+me)|commit|kommit|komit)''
    else if subcommand == "diff" then ''${git}(?:(?:a|the|that|to)[.,]?\s+)?(?:different|diff|dif|div|def|tiff|dev|this)''
    else if subcommand == "log" then ''${git}(?:log(?:ger)?|longer|luck)''
    else if subcommand == "add" then ''${git}(?:add|and)''
    else if subcommand == "push" then ''${git}(?:the\s+)?(?:push|pushed)''
    else if subcommand == "status" then ''${git}(?:status|started)''
    else if subcommand == "c" then ''${git}(?:c|see(?:\s+you)?|to\s+see(?:\s+you)?)''
    else if subcommand == "clone" then ''${git}(?:clone[d]?|the\s+clone|club|clear)''
    else if subcommand == "checkout" then ''${git}check[\s-]*out''
    else if subcommand == "rebase" then ''${git}re[\s-]*base''
    else if subcommand == "cherry-pick" then ''${git}cherry[\s-]*pick''
    else "${git}${subcommand}";
  tools = [
    { name = "zathura"; aliases = ''(?:[sz]ath?ura|[sz]ath?oura)''; }
    { name = "droix"; aliases = ''(?:droix|strikes|strokes)''; }
    { name = "ll"; aliases = ''(?:ll|list|and\s+ass|l[.\s-]*s)''; }
    { name = "nixpkgs"; aliases = ''(?:nixpkgs|xpkgs|(?:nick['’]?s|nix|next|no|mixed)\s+(?:p[.\s]*k[.\s]*g[.\s]*['’]?s|picky\s+g['’]?s|pick\s*,?\s*i\s+guess|pick\s+a\s+gaze|pekka\s+gays|baker\s*,?\s*i\s+guess|pick\s+a\s+kiss))''; }
    { name = "cargo"; aliases = ''(?:cargo|kargo|kind\s+of|car\s+golf|cargolf|caggle)''; }
    { name = "codex"; aliases = ''(?:codex|cool\s*,?\s+diggs)''; }
    { name = "ssh"; aliases = ''(?:s[.\s-]*s[.\s-]*h|as\s+aged|mrs\.?\s+h|it['’]?s\s+h)''; }
    { name = "hx"; aliases = ''(?:hx|h\s*x|h\s+ex|ha\s+iks|helix|felix|hey[\s,–—-]+lex|relax)''; }
    { name = "htop"; aliases = ''(?:htop|h[\s-]+top|age\s+tops?|ha\s+top|it\s+stopped|it['’]?s\s+(?:top|tough)|each\s+top(?:\s+five)?)''; }
    { name = "nvtop"; aliases = ''(?:nvtop|n\s*v\s*top|envy\s+top|en\s+vau\s+top)''; }
    { name = "rg"; aliases = ''(?:r[.\s-]*[gd](?:[.\s-]+r[.\s-]*g)?|are\s+gee|er\s+ge|lip\s+gap|rip\s*gr[ae]?[bp])''; }
    { name = "fd"; aliases = ''(?:fd|f[.\s-]+d|eff\s+dee|ef\s+de|find(?:\s+it)?|fine)''; }
    { name = "jaq"; aliases = ''(?:jaq|jack|jac|jay\s+cue)''; }
    { name = "systemctl"; aliases = ''system\s*(?:ctl|city\s+r|c\s*t\s*l)''; }
    { name = "journalctl"; aliases = ''(?:journal\s*,?\s*(?:ctl|cdl|citiel|c\s*t\s*l)|jean(?:[-\s]+(?:anthony|anne|ann|marc))?\s*,?\s*(?:c[.\s]*[td][.\s]*l|c[.\s]*t[.\s]*r|c[.\s]*t[.\s]*a[.\s]*r|sit\s+down|sidial|sidier|citiel)|john\s+(?:c[.\s]*[td][.\s]*l|c[.\s]*gales?|octl|city\s+(?:hall|health)|(?:on\s+)?ctl)|stronghold\s+city\s+hall)''; }
    { name = "nix-shell"; aliases = ''(?:nix|nicks|nyx)[\s-]+shell''; }
    { name = "nixos-rebuild"; aliases = ''(?:nixos|nix\s+os|nicks\s+os)[\s-]+rebuild''; }
  ];
  executables = [
    "nix" "nxd" "gh" "gitui" "difft" "bat" "tldr" "rga" "yq" "fzf" "lsd"
    "rustc" "trunk" "node" "npm" "pnpm" "yarn" "deno" "python3" "pip" "poetry"
    "make" "docker" "ssh" "rsync" "curl" "wget" "aws" "rclone" "ffmpeg" "mpv"
    "yt-dlp" "magick" "pandoc" "kitty" "firefox" "zeditor" "dolphin" "blender"
    "freecad" "inkscape" "gimp" "krita" "darktable" "obs" "codex" "opencode"
    "upgrade" "update" "enter" "tree"
  ];
  commandHeads = builtins.concatStringsSep "|" (
    (map (tool: tool.aliases) tools) ++ executables ++ [
      gitHeads "nicks" "next" "nyx" "mix"
      "nixs" "nx" "kargo" "cd" "ls" "cat" "mkdir" "cp" "mv" "rm" "npx"
      "bun" "tsc" "rustup"
    ]
  );
  subcommands = builtins.concatStringsSep "|" (gitCommands ++ [
    "different" "dif" "div" "def" "tiff" "this" "logger" "longer" "luck" "the" "and" "pushed" "cloned" "flake" "update" "check" "build" "develop"
    "shell" "run" "eval" "fmt" "lock" "test" "clippy" "clean" "doc" "install"
    "remove" "bench" "publish" "metadata" "tree" "dev" "exec" "dlx"
  ]);
  # Only command grammar boundaries, not punctuation inside argument tokens.
  boundaryCleanup = builtins.concatMap (depth:
    let
      managers = "${gitHeads}|nix|nicks|next|nyx|mix|cargo|kargo|npm|pnpm|yarn|bun|docker|gh|rustup";
      prefix = if depth == 0 then ''(\s*(?:${commandHeads}))''
        else if depth == 1 then ''(\s*(?:${managers})\s+(?:${subcommands}))''
        else ''(\s*(?:(?:nix|nicks|next|nyx)\s+flake|${gitHeads}\s+(?:remote|stash|worktree|submodule|bisect))\s+(?:${subcommands}))'';
    in [
      {
        name = "command-comma-${toString depth}";
        pattern = ''(?i)^${prefix},+\s*(\S)'';
        replace = "$1 $2";
      }
      {
        name = "command-period-${toString depth}";
        # Don't consume .#flake, ./path, ../path or a standalone literal dot.
        pattern = ''(?i)^${prefix}\.+\s*([[:alnum:]_"'-])'';
        excludePattern = ''(?i)^${prefix}\.\s*hash[ -]?tag\b'';
        replace = "$1 $2";
      }
    ]) [ 0 1 2 ];

in
# Anchoring a regex is insufficient when a pause starts a later streamed fragment.
map (rule: rule // { sessionStartOnly = true; }) (boundaryCleanup ++ [
  {
    name = "leading-get-is-git";
    pattern = ''(?i)^\s*get\b'';
    replace = "git";
  }
  (command "git" ''(?:git|skid|skit)'')
  {
    name = "nix-joined-subcommand";
    pattern = ''(?i)^\s*(?:nix|nicks|nyx|next)[\s,-]*(run|build|develop|shell|eval|fmt|log)\b'';
    replace = "nix $1";
  }
  {
    name = "nix-attached-flake-reference";
    pattern = ''(?i)^(nix\s+(?:run|build|develop|shell|eval))(\.(?:#|hash[ -]?tag\b)|#)'';
    replace = "$1 $2";
  }
  {
    name = "nix-flake-dot-hashtag";
    pattern = ''(?i)^(nix\s+(?:run|build|develop|shell|eval)\s+\.)\s+(hash[ -]?tag\b|#)'';
    replace = "$1$2";
  }
  # Complete phrase only: keep "get the clone ..." available to git clone.
  (command "git diff" ''(?:git|get)\s+the'')
  (command "nix flake update" nixFlakeUpdate)
  (withArguments "nix flake update" nixFlakeUpdate)
  (command "git add ." ''${gitAlias "add"}\s+(?:dot|punkt)'' )
  (command "git c -a" ''${gitAlias "c"}\s+(?:dash|minus)\s+a'' )
  (command "git commit -a" ''${gitAlias "commit"}\s+(?:dash|minus)\s+a'' )
  {
    name = "git-commit-spoken-message-option";
    pattern = ''(?i)^\s*${gitAlias "commit"}\s+(?:dash|minus)\s+m\s+(.+)$'';
    replace = "git commit -m $1";
  }
]
++ (map (sub: {
  name = "attached-git-${sub}-option";
  pattern = ''(?i)^\s*${gitAlias sub}(-{1,2}[a-z])'';
  replace = "git ${sub} $1";
}) gitCommands)
++ (map (sub: command "git ${sub}" (gitAlias sub)) gitCommands)
++ (map (sub: withArguments "git ${sub}" (gitAlias sub)) gitCommands)
++ (map (sub: command "nix ${sub}" "${nix}${sub}") nixCommands)
++ (map (sub: withArguments "nix ${sub}" "${nix}${sub}") nixCommands)
++ [
  {
    name = "nix-flake-update-input-trailing-period";
    pattern = ''(?i)^(nix\s+flake\s+update(?:\s+(?:${knownFlakeInput}))+)[.]+\s*$'';
    replace = "$1";
  }
]
++ (map (input: {
  name = "nix-flake-update-input-${input}";
  # Canonicalize leading bare input names, preserving quoted text and flag values.
  pattern = ''(?i)^(nix\s+flake\s+update(?:\s+(?:${knownFlakeInput}))*)\s+${input}(\s|$)'';
  replace = "$1 ${input}$2";
}) flakeInputs)
++ (map (sub: command "cargo ${sub}" "${cargo}${sub}") [
  "build" "test" "check" "run" "fmt" "clippy" "clean" "doc" "update"
  "add" "remove" "install" "bench" "publish" "metadata" "tree"
])
++ (map (sub: withArguments "cargo ${sub}" "${cargo}${sub}") [
  "build" "test" "check" "run" "fmt" "clippy" "doc"
  "add" "remove" "install" "bench" "publish" "metadata" "tree" "update" "clean"
])
++ (builtins.concatMap (manager: builtins.concatMap (sub: [
  (command "${manager} ${sub}" "${manager}\\s+${sub}")
  (withArguments "${manager} ${sub}" "${manager}\\s+${sub}")
]) [ "install" "add" "remove" "run" "test" "build" "dev" "exec" "dlx" "update" ])
  [ "npm" "pnpm" "yarn" "bun" ])
++ (map (tool: command tool.name tool.aliases) tools)
++ (map (tool: withArguments tool.name tool.aliases) tools)
++ (builtins.concatMap (name: [ (command name name) (withArguments name name) ]) executables)
++ [
  {
    name = "leading-the-is-zoxide";
    # German-accented z can be transcribed as the English article.
    pattern = ''(?i)^\s*the\b'';
    replace = "z";
  }
  # Repair known spoken directory names before splitting other leading z forms.
  (command "z dot" ''(?:z|zee|zed|zett|c|see|si)(?:[\s,_–—-]*|[\s,]+(?:dash|minus)[\s,]+)dot'')
  (command "z droix" ''(?:z|zee|zed|zett|c|see(?:\s+you)?|si)(?:[\s,._–—-]*|[\s,]+(?:dash|minus)[\s,]+)(?:${droixName}|draw[\s_–—-]*x)'')
  (command "z" ''(?:z|zee|zed|zett|c|see|si)'')
  {
    name = "zoxide";
    # Terminal z is always zoxide; lowercase every query token in all languages,
    # including streamed fragments and multi-token/path-like queries.
    pattern = ''(?i)^\s*(?:z|zee|zed|zett|c|see(?:\s+you)?|si)(?:\s*[–—-]\s*|[.?!,;:]+\s*|\s+)(.+?)\s*$'';
    replace = "z $1";
    lowercase = true;
  }
  {
    name = "zoxide-attached-path";
    # Any joined leading z is a zoxide command, except the canonical application.
    # Application aliases above must run before this rule.
    pattern = ''(?i)^\s*z(\S.*?)\s*$'';
    excludePattern = ''(?i)^\s*(?:zathura(?:\s|$)|(?:zee|zed|zett)(?:[\s.?!,;:–—-]|$))'';
    replace = "z $1";
    lowercase = true;
  }
  {
    name = "zoxide-recognition-punctuation";
    # Preserve literal . and .. queries, and dots inside names.
    pattern = ''^(z\s+.*[^\s.!?,])[.!?,]+\s*$'';
    replace = "$1";
  }
]
++ [
  {
    name = "git-recognition-trailing-period";
    # Run before spoken punctuation so an explicitly dictated dot survives.
    # A standalone . / .. argument and periods inside quotes are not sentence stops.
    pattern = ''(?is)^(git\s+.*[^\s.])\.+\s*$'';
    excludePattern = ''\s--\s'';
    replace = "$1";
  }
  {
    name = "shell-spoken-punctuation";
    pattern = ''(?is)^\s*((?:git|rg|fd|ll|ls|cd|hx|htop|nvtop|nix|nixpkgs|cargo|rustc|rustup|npm|pnpm|yarn|node|npx|bun|deno|tsc|trunk|codex|droix|zathura|ssh|systemctl|journalctl|docker|curl|wget|bat|cat|mkdir|rm|cp|mv|z)\b.*)$'';
    replace = "$1";
    spokenPunctuation = "shell";
  }
]) ++ [
  {
    name = "identifier-spoken-punctuation";
    pattern = ''(?s)^(.*)$'';
    replace = "$1";
    spokenPunctuation = "identifier";
  }
]
