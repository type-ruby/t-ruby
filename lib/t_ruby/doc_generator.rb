# frozen_string_literal: true

require "json"
require "fileutils"

module TRuby
  # API Documentation Generator
  class DocGenerator
    attr_reader :docs, :config

    def initialize(config = nil)
      @config = config || Config.new
      @docs = {
        types: {},
        interfaces: {},
        functions: {},
        modules: {}
      }
      @parser = nil
    end

    # Generate documentation from source files
    def generate(paths, output_dir: "docs")
      puts "Generating T-Ruby API Documentation..."

      # Parse all files
      files = collect_files(paths)
      files.each { |file| parse_file(file) }

      # Generate output
      FileUtils.mkdir_p(output_dir)

      generate_index(output_dir)
      generate_type_docs(output_dir)
      generate_interface_docs(output_dir)
      generate_function_docs(output_dir)
      generate_module_docs(output_dir)
      generate_search_index(output_dir)

      puts "Documentation generated in #{output_dir}/"
      @docs
    end

    # Generate single-file markdown documentation
    def generate_markdown(paths, output_path: "API.md")
      files = collect_files(paths)
      files.each { |file| parse_file(file) }

      md = []
      md << "# T-Ruby API Documentation"
      md << ""
      md << "**Generated:** #{Time.now}"
      md << ""
      md << "## Table of Contents"
      md << ""
      md << "- [Types](#types)"
      md << "- [Interfaces](#interfaces)"
      md << "- [Functions](#functions)"
      md << ""

      # Types section
      md << "## Types"
      md << ""
      @docs[:types].each do |name, info|
        md << "### `#{name}`"
        md << ""
        md << "```typescript"
        md << "type #{name} = #{info[:definition]}"
        md << "```"
        md << ""
        md << info[:description] if info[:description]
        md << ""
        md << "**Source:** `#{info[:source]}`" if info[:source]
        md << ""
      end

      # Interfaces section
      md << "## Interfaces"
      md << ""
      @docs[:interfaces].each do |name, info|
        md << "### `#{name}`"
        md << ""
        md << info[:description] if info[:description]
        md << ""

        if info[:type_params]&.any?
          md << "**Type Parameters:** `<#{info[:type_params].join(', ')}>`"
          md << ""
        end

        if info[:members]&.any?
          md << "#### Members"
          md << ""
          md << "| Name | Type | Description |"
          md << "|------|------|-------------|"
          info[:members].each do |member|
            md << "| `#{member[:name]}` | `#{member[:type]}` | #{member[:description] || '-'} |"
          end
          md << ""
        end

        md << "**Source:** `#{info[:source]}`" if info[:source]
        md << ""
      end

      # Functions section
      md << "## Functions"
      md << ""
      @docs[:functions].each do |name, info|
        md << "### `#{name}`"
        md << ""
        md << info[:description] if info[:description]
        md << ""

        # Signature
        params = info[:params]&.map { |p| "#{p[:name]}: #{p[:type]}" }&.join(", ") || ""
        type_params = info[:type_params]&.any? ? "<#{info[:type_params].join(', ')}>" : ""
        md << "```ruby"
        md << "def #{name}#{type_params}(#{params}): #{info[:return_type] || 'void'}"
        md << "```"
        md << ""

        if info[:params]&.any?
          md << "#### Parameters"
          md << ""
          md << "| Name | Type | Description |"
          md << "|------|------|-------------|"
          info[:params].each do |param|
            md << "| `#{param[:name]}` | `#{param[:type]}` | #{param[:description] || '-'} |"
          end
          md << ""
        end

        md << "**Returns:** `#{info[:return_type]}`" if info[:return_type]
        md << ""
        md << "**Source:** `#{info[:source]}`" if info[:source]
        md << ""
      end

      File.write(output_path, md.join("\n"))
      puts "Documentation generated: #{output_path}"
    end

    # Generate JSON documentation
    def generate_json(paths, output_path: "api.json")
      files = collect_files(paths)
      files.each { |file| parse_file(file) }

      File.write(output_path, JSON.pretty_generate({
        generated_at: Time.now.iso8601,
        version: TRuby::VERSION,
        types: @docs[:types],
        interfaces: @docs[:interfaces],
        functions: @docs[:functions],
        modules: @docs[:modules]
      }))

      puts "JSON documentation generated: #{output_path}"
    end

    private

    def parser
      @parser ||= Parser.new("")
    end

    def collect_files(paths)
      files = []
      paths.each do |path|
        if File.directory?(path)
          files.concat(Dir.glob(File.join(path, "**", "*.trb")))
          files.concat(Dir.glob(File.join(path, "**", "*.d.trb")))
        elsif File.file?(path)
          files << path
        end
      end
      files.uniq
    end

    def parse_file(file_path)
      content = File.read(file_path)
      relative_path = file_path.sub("#{Dir.pwd}/", "")

      # Extract documentation comments
      doc_comments = extract_doc_comments(content)

      # Parse type aliases
      content.scan(/^type\s+(\w+)(?:<([^>]+)>)?\s*=\s*(.+)$/) do |name, type_params, definition|
        @docs[:types][name] = {
          name: name,
          type_params: type_params&.split(/\s*,\s*/),
          definition: definition.strip,
          description: doc_comments["type:#{name}"],
          source: relative_path
        }
      end

      # Parse interfaces
      parse_interfaces(content, relative_path, doc_comments)

      # Parse functions
      parse_functions(content, relative_path, doc_comments)
    end

    def extract_doc_comments(content)
      comments = {}
      current_comment = []
      current_target = nil

      content.each_line do |line|
        if line =~ /^\s*#\s*@doc\s+(\w+):(\w+)/
          current_target = "#{Regexp.last_match(1)}:#{Regexp.last_match(2)}"
          current_comment = []
        elsif line =~ /^\s*#\s*(.+)/ && current_target
          current_comment << Regexp.last_match(1).strip
        elsif line !~ /^\s*#/ && current_target
          comments[current_target] = current_comment.join(" ")
          current_target = nil
          current_comment = []
        end

        # Also check inline comments before definitions
        if line =~ /^\s*#\s*(.+)$/
          current_comment << Regexp.last_match(1).strip
        elsif line =~ /^(type|interface|def)\s+(\w+)/
          type = Regexp.last_match(1)
          name = Regexp.last_match(2)
          unless current_comment.empty?
            comments["#{type}:#{name}"] = current_comment.join(" ")
          end
          current_comment = []
        end
      end

      comments
    end

    def parse_interfaces(content, source, doc_comments)
      # Match interface blocks
      content.scan(/interface\s+(\w+)(?:<([^>]+)>)?\s*\n((?:(?!^end).)*?)^end/m) do |name, type_params, body|
        members = []

        body.scan(/^\s*(\w+[\?\!]?)\s*:\s*(.+)$/) do |member_name, member_type|
          members << {
            name: member_name,
            type: member_type.strip,
            description: doc_comments["member:#{name}.#{member_name}"]
          }
        end

        @docs[:interfaces][name] = {
          name: name,
          type_params: type_params&.split(/\s*,\s*/),
          members: members,
          description: doc_comments["interface:#{name}"],
          source: source
        }
      end
    end

    def parse_functions(content, source, doc_comments)
      # Match function definitions
      content.scan(/def\s+(\w+[\?\!]?)(?:<([^>]+)>)?\s*\(([^)]*)\)(?:\s*:\s*(.+?))?(?:\n|$)/) do |name, type_params, params_str, return_type|
        params = []

        params_str.scan(/(\w+)\s*:\s*([^,]+)/) do |param_name, param_type|
          params << {
            name: param_name,
            type: param_type.strip,
            description: doc_comments["param:#{name}.#{param_name}"]
          }
        end

        @docs[:functions][name] = {
          name: name,
          type_params: type_params&.split(/\s*,\s*/),
          params: params,
          return_type: return_type&.strip,
          description: doc_comments["def:#{name}"],
          source: source
        }
      end
    end

    def generate_index(output_dir)
      html = <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <title>T-Ruby API Documentation</title>
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 40px; }
            h1 { color: #cc342d; }
            .section { margin: 20px 0; }
            a { color: #0366d6; text-decoration: none; }
            a:hover { text-decoration: underline; }
            .item { padding: 5px 0; }
            code { background: #f6f8fa; padding: 2px 6px; border-radius: 3px; }
          </style>
        </head>
        <body>
          <h1>T-Ruby API Documentation</h1>
          <p>Generated: #{Time.now}</p>

          <div class="section">
            <h2>Types (#{@docs[:types].size})</h2>
            #{@docs[:types].keys.sort.map { |name| "<div class='item'><a href='types/#{name}.html'><code>#{name}</code></a></div>" }.join}
          </div>

          <div class="section">
            <h2>Interfaces (#{@docs[:interfaces].size})</h2>
            #{@docs[:interfaces].keys.sort.map { |name| "<div class='item'><a href='interfaces/#{name}.html'><code>#{name}</code></a></div>" }.join}
          </div>

          <div class="section">
            <h2>Functions (#{@docs[:functions].size})</h2>
            #{@docs[:functions].keys.sort.map { |name| "<div class='item'><a href='functions/#{name}.html'><code>#{name}</code></a></div>" }.join}
          </div>
        </body>
        </html>
      HTML

      File.write(File.join(output_dir, "index.html"), html)
    end

    def generate_type_docs(output_dir)
      types_dir = File.join(output_dir, "types")
      FileUtils.mkdir_p(types_dir)

      @docs[:types].each do |name, info|
        html = generate_type_html(name, info)
        File.write(File.join(types_dir, "#{name}.html"), html)
      end
    end

    def generate_interface_docs(output_dir)
      interfaces_dir = File.join(output_dir, "interfaces")
      FileUtils.mkdir_p(interfaces_dir)

      @docs[:interfaces].each do |name, info|
        html = generate_interface_html(name, info)
        File.write(File.join(interfaces_dir, "#{name}.html"), html)
      end
    end

    def generate_function_docs(output_dir)
      functions_dir = File.join(output_dir, "functions")
      FileUtils.mkdir_p(functions_dir)

      @docs[:functions].each do |name, info|
        html = generate_function_html(name, info)
        File.write(File.join(functions_dir, "#{name}.html"), html)
      end
    end

    def generate_module_docs(output_dir)
      # Placeholder for module documentation
    end

    def generate_search_index(output_dir)
      search_data = []

      @docs[:types].each do |name, info|
        search_data << { type: "type", name: name, url: "types/#{name}.html" }
      end

      @docs[:interfaces].each do |name, info|
        search_data << { type: "interface", name: name, url: "interfaces/#{name}.html" }
      end

      @docs[:functions].each do |name, info|
        search_data << { type: "function", name: name, url: "functions/#{name}.html" }
      end

      File.write(File.join(output_dir, "search-index.json"), JSON.generate(search_data))
    end

    def generate_type_html(name, info)
      <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <title>#{name} - T-Ruby API</title>
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 40px; }
            h1 { color: #cc342d; }
            pre { background: #f6f8fa; padding: 16px; border-radius: 6px; overflow-x: auto; }
            .meta { color: #6a737d; font-size: 14px; }
            a { color: #0366d6; }
          </style>
        </head>
        <body>
          <a href="../index.html">← Back to Index</a>
          <h1>type #{name}</h1>
          #{info[:description] ? "<p>#{info[:description]}</p>" : ""}
          <pre>type #{name}#{info[:type_params] ? "<#{info[:type_params].join(', ')}>" : ""} = #{info[:definition]}</pre>
          <p class="meta">Source: <code>#{info[:source]}</code></p>
        </body>
        </html>
      HTML
    end

    def generate_interface_html(name, info)
      members_html = info[:members]&.map do |m|
        "<tr><td><code>#{m[:name]}</code></td><td><code>#{m[:type]}</code></td><td>#{m[:description] || '-'}</td></tr>"
      end&.join || ""

      <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <title>#{name} - T-Ruby API</title>
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 40px; }
            h1 { color: #cc342d; }
            table { border-collapse: collapse; width: 100%; }
            th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
            th { background: #f6f8fa; }
            pre { background: #f6f8fa; padding: 16px; border-radius: 6px; }
            .meta { color: #6a737d; font-size: 14px; }
            a { color: #0366d6; }
          </style>
        </head>
        <body>
          <a href="../index.html">← Back to Index</a>
          <h1>interface #{name}#{info[:type_params] ? "&lt;#{info[:type_params].join(', ')}&gt;" : ""}</h1>
          #{info[:description] ? "<p>#{info[:description]}</p>" : ""}
          #{"<h2>Members</h2><table><tr><th>Name</th><th>Type</th><th>Description</th></tr>#{members_html}</table>" unless members_html.empty?}
          <p class="meta">Source: <code>#{info[:source]}</code></p>
        </body>
        </html>
      HTML
    end

    def generate_function_html(name, info)
      params_html = info[:params]&.map do |p|
        "<tr><td><code>#{p[:name]}</code></td><td><code>#{p[:type]}</code></td><td>#{p[:description] || '-'}</td></tr>"
      end&.join || ""

      params_sig = info[:params]&.map { |p| "#{p[:name]}: #{p[:type]}" }&.join(", ") || ""
      type_params = info[:type_params]&.any? ? "<#{info[:type_params].join(', ')}>" : ""

      <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <title>#{name} - T-Ruby API</title>
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 40px; }
            h1 { color: #cc342d; }
            table { border-collapse: collapse; width: 100%; }
            th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
            th { background: #f6f8fa; }
            pre { background: #f6f8fa; padding: 16px; border-radius: 6px; }
            .meta { color: #6a737d; font-size: 14px; }
            a { color: #0366d6; }
          </style>
        </head>
        <body>
          <a href="../index.html">← Back to Index</a>
          <h1>#{name}</h1>
          #{info[:description] ? "<p>#{info[:description]}</p>" : ""}
          <h2>Signature</h2>
          <pre>def #{name}#{type_params}(#{params_sig}): #{info[:return_type] || 'void'}</pre>
          #{"<h2>Parameters</h2><table><tr><th>Name</th><th>Type</th><th>Description</th></tr>#{params_html}</table>" unless params_html.empty?}
          <h2>Returns</h2>
          <p><code>#{info[:return_type] || 'void'}</code></p>
          <p class="meta">Source: <code>#{info[:source]}</code></p>
        </body>
        </html>
      HTML
    end
  end
end
