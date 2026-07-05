import Foundation

enum Help {
    static let usage = """
    qaz - Download GitHub release assets

    USAGE:
        qaz <repository> [OPTIONS]

    REPOSITORY FORMATS:
        owner/repo              Short form
        owner/repo.git          With .git suffix
        https://github.com/owner/repo           Full URL
        https://github.com/owner/repo/          Trailing slash
        https://github.com/owner/repo/releases/tag/v1.0.0    URL with tag

    OPTIONS:
        -q, --quiet         Suppress output (default)
        -i, --interactive   Select asset interactively
        -v, --verbose       Show detailed output
        -t, --tag TAG       Download specific release tag
        -d, --directory DIR Download to directory (default: current)
        -I, --install       Install after download
        -h, --help          Show this help

    EXAMPLES:
        qaz BurntSushi/ripgrep
        qaz https://github.com/cli/cli/releases/tag/v2.65.0
        qaz jj-vcs/jj -v --install
        qaz owner/repo -t v1.0.0 -d ~/bin

    INSTALLATION:
        With --install flag:
            .app bundles  -> ~/Applications/
            CLI binaries  -> ~/.local/bin/
            DMG files     -> Auto-mount and extract

    ENVIRONMENT:
        GITHUB_TOKEN or GH_TOKEN
            GitHub API token for higher rate limits
            (5000 requests/hour vs 60 unauthenticated)
    """
}
