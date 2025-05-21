# GitHub Repository Manager

A Ruby command-line tool to list, filter, and clone repositories from a GitHub user or organisation. This script utilizes the GitHub CLI (`gh`) to fetch repository information and provides various output formats and filtering options.

## Prerequisites

- [GitHub CLI](https://cli.github.com/) installed and authenticated
- Ruby (2.5 or higher recommended)
- Required gems will be automatically installed ([colorize](https://github.com/fazibear/colorize), [terminal-table](https://github.com/tj/terminal-table))

## Features

- List all repositories for a specified GitHub user/organization
- Filter repositories by visibility (public, private, internal)
- Sort repositories by name, creation date, or last pushed date
- Display output in different formats (simple table, full details, JSON)
- Save output to a file
- Clone multiple repositories in a single command
- Update existing repositories

## Usage

Make the script executable:

```bash
chmod +x github-repo-manager.rb
```

Basic usage:

```bash
./github-repo-manager.rb -o OWNER
```

## Options

| Option | Long option | Description | Default value |
|--------|-------------|-------------|---------------|
| `-o` | `--owner OWNER` | GitHub user/organisation name (required) | None |
| `-v` | `--visibility TYPE` | Repository visibility filter (all, public, private, internal) | all |
| `-f` | `--format FORMAT` | Output format (simple, full, json) | simple |
| `-s` | `--sort FIELD` | Sort field (name, pushed, created) | name |
| N/A | `--output FILE` | Write output to file | None |
| `-c` | `--clone` | Clone repositories | false |
| `-d` | `--directory DIR` | Directory to clone repositories into | Current directory |
| `-h` | `--help` | Show help message | N/A |

## Example Commands

List all repositories in a simple table format:

```bash
./github-repo-manager.rb -o OWNER
```

List only public repositories sorted by last pushed date:

```bash
./github-repo-manager.rb -o OWNER -v public -s pushed
```

Generate a detailed listing in JSON format and save to a file:

```bash
./github-repo-manager.rb -o OWNER -f json --output repos.json
```

List repositories with full details:

```bash
./github-repo-manager.rb -o OWNER -f full
```

Clone all repositories to a specific directory:

```bash
./github-repo-manager.rb -o OWNER -c -d ~/repos
```

Clone only private repositories:

```bash
./github-repo-manager.rb -o OWNER -v private -c
```

## Output Formats

### Simple (default)
Displays repositories in a nicely formatted table with key information.

### Full
Provides comprehensive details for each repository including:
- Name and visibility
- URL and SSH URL
- Description
- Last pushed and creation dates

### JSON
Outputs raw JSON data which can be used for further processing by other tools.

## Note

This script requires proper GitHub CLI authentication. Make sure you've authenticated using:

```bash
gh auth login
```

If you're working with organizations, ensure you have the necessary permissions to access the repositories.
