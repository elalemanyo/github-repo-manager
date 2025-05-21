#!/usr/bin/env ruby

require "json"
require "optparse"
require "fileutils"

begin
  require "bundler/inline"
rescue LoadError
  puts "Bundler not available. Installing..."
  system("gem install bundler")
  require "bundler/inline"
end

gemfile do
  source "https://rubygems.org"
  gem "time"
  gem "colorize"
  gem "terminal-table"
end

class GitHubRepoManager
  attr_reader :options

  DEFAULT_OPTIONS = {
    owner: nil,
    visibility: "all", # all, public, private, internal
    format: "simple",  # simple, full, json
    sort: "name",      # name, pushed, created
    output_file: nil,  # file to write output to
    clone_dir: nil,    # directory to clone repositories into
    clone_repos: false # whether to clone repositories
  }

  def initialize
    @options = DEFAULT_OPTIONS.dup
    @stats = {
      cloned: 0,
      updated: 0,
      failed: 0
    }
    parse_options
    validate_options
  end

  def run
    repos = fetch_repositories

    formatted_output = format_output(repos)
    output_results(formatted_output)

    clone_repositories(repos) if options[:clone_repos]

    display_summary(repos)
  end

  def display_summary(repos)
    puts "\n============ SUMMARY ============".green
    puts "Found #{repos.size} repositories for #{options[:owner]}".green

    if options[:output_file]
      puts "Results written to: #{options[:output_file]}".green
    end

    if options[:clone_repos]
      clone_dir = options[:clone_dir] || Dir.pwd
      puts "Clone directory: #{clone_dir}".green
      puts "Repositories cloned: #{@stats[:cloned]}".green
      puts "Repositories updated: #{@stats[:updated]}".green
      puts "Failed operations: #{@stats[:failed]}".red if @stats[:failed] > 0
    end

    puts "====================================".green
  end

  private

  def parse_options
    OptionParser.new do |opts|
      opts.banner = "Usage: #{File.basename($0)} [options]"

      opts.on("-o", "--owner OWNER", "GitHub owner/organization name (required)") do |owner|
        options[:owner] = owner
      end

      opts.on("-v", "--visibility TYPE", "Repository visibility (all, public, private, internal)") do |v|
        if ["all", "public", "private", "internal"].include?(v)
          options[:visibility] = v
        else
          puts "Invalid visibility type. Using default: all".red
        end
      end

      opts.on("-f", "--format FORMAT", "Output format (simple, full, json)") do |f|
        if ["simple", "full", "json"].include?(f)
          options[:format] = f
        else
          puts "Invalid format. Using default: simple".red
        end
      end

      opts.on("-s", "--sort FIELD", "Sort repositories by (name, pushed, created)") do |s|
        if ["name", "pushed", "created"].include?(s)
          options[:sort] = s
        else
          puts "Invalid sort field. Using default: name".red
        end
      end

      opts.on("--output FILE", "Write output to file") do |file|
        options[:output_file] = file
      end

      opts.on("-c", "--clone", "Clone repositories") do
        options[:clone_repos] = true
      end

      opts.on("-d", "--directory DIR", "Directory to clone repositories into") do |dir|
        options[:clone_dir] = dir
      end

      opts.on("-h", "--help", "Show this help message") do
        puts opts
        exit
      end
    end.parse!
  end

  def validate_options
    if options[:owner].nil?
      puts "Error: Owner parameter is required".red
      puts "Use --help for more information".yellow
      exit 1
    end
  end

  def fetch_repositories
    cmd = "gh repo list #{options[:owner]} --limit 1000"
    cmd += " --visibility #{options[:visibility]}" unless options[:visibility] == "all"
    cmd += " --json name,url,description,pushedAt,createdAt,sshUrl,visibility"

    begin
      puts "Fetching repositories for owner: #{options[:owner]}...".yellow
      output = JSON.parse(`#{cmd}`)

      sort_repositories(output)
    rescue => e
      puts "Error executing GitHub CLI command: #{e.message}".red
      puts "Make sure GitHub CLI (gh) is installed and you are authenticated".red
      exit 1
    end
  end

  def sort_repositories(repos)
    case options[:sort]
    when "pushed"
      repos.sort_by { |repo| repo["pushedAt"] || "" }.reverse
    when "created"
      repos.sort_by { |repo| repo["createdAt"] || "" }.reverse
    else
      repos.sort_by { |repo| repo["name"].downcase }
    end
  end

  def format_output(repos)
    case options[:format]
    when "full"
      repos.map do |repo|
        visibility_info = repo["visibility"] ? " (#{repo["visibility"]})" : ""
        [
          "#{repo["name"]}#{visibility_info}",
          "  URL: #{repo["url"]}",
          "  SSH: #{repo["sshUrl"] || "N/A"}",
          "  Description: #{repo["description"] || "No description"}",
          "  Last pushed: #{format_date(repo["pushedAt"])}",
          "  Created: #{format_date(repo["createdAt"])}"
        ].join("\n")
      end.join("\n\n")
    when "json"
      JSON.pretty_generate(repos)
    else
      table = Terminal::Table.new(
        title: "Repositories for #{options[:owner]}".green,
        headings: ["Name", "Visibility", "Last Updated", "Created At", "Description"],
        rows: repos.map do |repo|
          [
            repo["name"].colorize(:light_blue),
            repo["visibility"] || "N/A",
            format_date(repo["pushedAt"]),
            format_date(repo["createdAt"]),
            truncate_text(repo["description"] || "No description", 50)
          ]
        end
      )
      table.to_s
    end
  end

  def truncate_text(text, max_length)
    (text.length > max_length) ? "#{text[0...max_length]}..." : text
  end

  def format_date(date_string)
    return "N/A" unless date_string
    begin
      Time.parse(date_string).strftime("%Y-%m-%d %H:%M:%S")
    rescue
      date_string
    end
  end

  def output_results(formatted_output)
    if options[:output_file]
      begin
        File.write(options[:output_file], formatted_output)
        puts "Results written to #{options[:output_file]}".green
      rescue => e
        puts "Error writing to file: #{e.message}".red
      end
    else
      puts formatted_output
    end
  end

  def clone_repositories(repos)
    clone_dir = options[:clone_dir] || Dir.pwd

    FileUtils.mkdir_p(clone_dir) unless File.directory?(clone_dir)
    puts "\nCloning repositories to: #{clone_dir}".yellow

    clone_sequentially(repos, clone_dir)
  end

  def clone_sequentially(repos, clone_dir)
    repos.each_with_index do |repo, index|
      repo_name = repo["name"]

      puts "\n[#{index + 1}/#{repos.size}] Cloning #{repo_name}...".yellow
      clone_single_repository(repo_name, clone_dir)
    end
  end

  def clone_single_repository(repo_name, clone_dir)
    target_dir = File.join(clone_dir, repo_name)
    if File.directory?(target_dir)
      puts "  Repository '#{repo_name}' already exists, updating instead...".yellow

      if system("git -C #{target_dir} pull")
        puts "  Successfully updated #{repo_name}".green
        @stats[:updated] += 1
      else
        puts "  Failed to update #{repo_name}".red
        @stats[:failed] += 1
      end
    else
      puts "  Cloning repository '#{repo_name}'...".yellow
      clone_cmd = "gh repo clone #{options[:owner]}/#{repo_name} #{target_dir}"

      if system(clone_cmd)
        puts "  Successfully cloned #{repo_name}".green
        @stats[:cloned] += 1
      else
        puts "  Failed to clone #{repo_name}".red
        @stats[:failed] += 1
      end
    end
  end
end

GitHubRepoManager.new.run
