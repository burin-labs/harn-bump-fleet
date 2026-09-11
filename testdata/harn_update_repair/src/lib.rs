use std::path::Path;

pub fn parent(path: &Path) -> Option<&Path> {
    let parent = if let Some(parent) = path.parent() {
        parent
    } else {
        return None;
    };
    Some(parent)
}

pub fn command_line(program: &str) -> String {
    let args = vec![program.to_string()];
    args.join(" ")
}
