# frozen_string_literal: true

require "spec_helper"
require "stringio"

RSpec.describe TRuby::LSPServer do
  let(:input) { StringIO.new }
  let(:output) { StringIO.new }
  let(:server) { described_class.new(input: input, output: output) }

  # Helper to create LSP messages
  def create_message(content)
    json = JSON.generate(content)
    "Content-Length: #{json.bytesize}\r\n\r\n#{json}"
  end

  # Helper to send a message and get response
  def send_request(method, params = {}, id: 1)
    message = {
      "jsonrpc" => "2.0",
      "id" => id,
      "method" => method,
      "params" => params
    }
    input.string = create_message(message)
    input.rewind

    response = server.handle_message(server.read_message)
    response
  end

  # Helper to send notification (no id)
  def send_notification(method, params = {})
    message = {
      "jsonrpc" => "2.0",
      "method" => method,
      "params" => params
    }
    input.string = create_message(message)
    input.rewind

    server.handle_message(server.read_message)
  end

  describe "message parsing" do
    it "reads LSP messages correctly" do
      message_content = { "jsonrpc" => "2.0", "id" => 1, "method" => "test" }
      input.string = create_message(message_content)
      input.rewind

      result = server.read_message
      expect(result).to eq(message_content)
    end

    it "handles empty input gracefully" do
      input.string = ""
      input.rewind

      result = server.read_message
      expect(result).to be_nil
    end
  end

  describe "initialize" do
    it "returns server capabilities" do
      response = send_request("initialize", {
        "processId" => 1234,
        "rootUri" => "file:///project",
        "capabilities" => {}
      })

      expect(response["result"]["capabilities"]).to include(
        "textDocumentSync" => hash_including("openClose" => true),
        "completionProvider" => hash_including("triggerCharacters" => [":", "<", "|", "&", "."]),
        "hoverProvider" => true,
        "definitionProvider" => true,
        "inlayHintProvider" => hash_including("resolveProvider" => false),
        "callHierarchyProvider" => true,
        "typeHierarchyProvider" => true,
        "foldingRangeProvider" => true
      )
    end

    it "returns server info" do
      response = send_request("initialize", {})

      expect(response["result"]["serverInfo"]).to eq({
        "name" => "t-ruby-lsp",
        "version" => TRuby::LSPServer::VERSION
      })
    end
  end

  describe "initialized" do
    it "accepts initialized notification" do
      # First initialize
      send_request("initialize", {})

      # Then initialized notification
      result = send_notification("initialized", {})
      expect(result).to be_nil
    end
  end

  describe "shutdown" do
    it "responds to shutdown request" do
      send_request("initialize", {})
      response = send_request("shutdown")

      expect(response["result"]).to be_nil
      expect(response["error"]).to be_nil
    end
  end

  describe "server not initialized error" do
    it "returns error for requests before initialization" do
      response = send_request("textDocument/completion", {})

      expect(response["error"]["code"]).to eq(TRuby::LSPServer::ErrorCodes::SERVER_NOT_INITIALIZED)
    end
  end

  describe "textDocument/didOpen" do
    before { send_request("initialize", {}) }

    it "stores opened document" do
      send_notification("textDocument/didOpen", {
        "textDocument" => {
          "uri" => "file:///test.trb",
          "languageId" => "t-ruby",
          "version" => 1,
          "text" => "def hello(name: String): String\nend"
        }
      })

      # Verify document was stored by checking hover works
      response = send_request("textDocument/hover", {
        "textDocument" => { "uri" => "file:///test.trb" },
        "position" => { "line" => 0, "character" => 4 }
      })

      expect(response["result"]).not_to be_nil
    end
  end

  describe "textDocument/didChange" do
    before do
      send_request("initialize", {})
      send_notification("textDocument/didOpen", {
        "textDocument" => {
          "uri" => "file:///test.trb",
          "version" => 1,
          "text" => "def old(): void\nend"
        }
      })
    end

    it "updates document content" do
      send_notification("textDocument/didChange", {
        "textDocument" => { "uri" => "file:///test.trb", "version" => 2 },
        "contentChanges" => [{ "text" => "def new_function(): String\nend" }]
      })

      response = send_request("textDocument/hover", {
        "textDocument" => { "uri" => "file:///test.trb" },
        "position" => { "line" => 0, "character" => 4 }
      })

      expect(response["result"]["contents"]["value"]).to include("new_function")
    end
  end

  describe "textDocument/didClose" do
    before do
      send_request("initialize", {})
      send_notification("textDocument/didOpen", {
        "textDocument" => {
          "uri" => "file:///test.trb",
          "version" => 1,
          "text" => "def hello(): void\nend"
        }
      })
    end

    it "removes document from storage" do
      send_notification("textDocument/didClose", {
        "textDocument" => { "uri" => "file:///test.trb" }
      })

      response = send_request("textDocument/hover", {
        "textDocument" => { "uri" => "file:///test.trb" },
        "position" => { "line" => 0, "character" => 0 }
      })

      expect(response["result"]).to be_nil
    end
  end

  describe "textDocument/completion" do
    before do
      send_request("initialize", {})
      send_notification("textDocument/didOpen", {
        "textDocument" => {
          "uri" => "file:///test.trb",
          "version" => 1,
          "text" => "type UserId = String\ndef get_user(id: ): UserId\nend"
        }
      })
    end

    it "provides built-in type completions after colon" do
      response = send_request("textDocument/completion", {
        "textDocument" => { "uri" => "file:///test.trb" },
        "position" => { "line" => 1, "character" => 17 } # After "id: "
      })

      items = response["result"]["items"]
      labels = items.map { |i| i["label"] }

      expect(labels).to include("String", "Integer", "Boolean", "Array", "Hash")
    end

    it "includes type aliases in completions" do
      response = send_request("textDocument/completion", {
        "textDocument" => { "uri" => "file:///test.trb" },
        "position" => { "line" => 1, "character" => 17 }
      })

      items = response["result"]["items"]
      labels = items.map { |i| i["label"] }

      expect(labels).to include("UserId")
    end

    it "provides keyword completions at line start" do
      send_notification("textDocument/didChange", {
        "textDocument" => { "uri" => "file:///test.trb", "version" => 2 },
        "contentChanges" => [{ "text" => "" }]
      })

      response = send_request("textDocument/completion", {
        "textDocument" => { "uri" => "file:///test.trb" },
        "position" => { "line" => 0, "character" => 0 }
      })

      items = response["result"]["items"]
      labels = items.map { |i| i["label"] }

      expect(labels).to include("type", "interface", "def", "end")
    end
  end

  describe "textDocument/hover" do
    before do
      send_request("initialize", {})
    end

    it "shows hover info for built-in types" do
      send_notification("textDocument/didOpen", {
        "textDocument" => {
          "uri" => "file:///test.trb",
          "version" => 1,
          "text" => "def test(name: String): Integer\nend"
        }
      })

      response = send_request("textDocument/hover", {
        "textDocument" => { "uri" => "file:///test.trb" },
        "position" => { "line" => 0, "character" => 16 } # On "String"
      })

      expect(response["result"]["contents"]["value"]).to include("String")
      expect(response["result"]["contents"]["value"]).to include("Built-in")
    end

    it "shows hover info for type aliases" do
      send_notification("textDocument/didOpen", {
        "textDocument" => {
          "uri" => "file:///test.trb",
          "version" => 1,
          "text" => "type UserId = String\ndef get(id: UserId): String\nend"
        }
      })

      response = send_request("textDocument/hover", {
        "textDocument" => { "uri" => "file:///test.trb" },
        "position" => { "line" => 0, "character" => 6 } # On "UserId"
      })

      expect(response["result"]["contents"]["value"]).to include("Type Alias")
      expect(response["result"]["contents"]["value"]).to include("UserId")
    end

    it "shows hover info for functions" do
      send_notification("textDocument/didOpen", {
        "textDocument" => {
          "uri" => "file:///test.trb",
          "version" => 1,
          "text" => "def greet(name: String): String\n  \"Hello\"\nend"
        }
      })

      response = send_request("textDocument/hover", {
        "textDocument" => { "uri" => "file:///test.trb" },
        "position" => { "line" => 0, "character" => 5 } # On "greet"
      })

      expect(response["result"]["contents"]["value"]).to include("Function")
      expect(response["result"]["contents"]["value"]).to include("greet")
    end

    it "shows hover info for interfaces" do
      send_notification("textDocument/didOpen", {
        "textDocument" => {
          "uri" => "file:///test.trb",
          "version" => 1,
          "text" => "interface Printable\n  to_string: String\nend"
        }
      })

      response = send_request("textDocument/hover", {
        "textDocument" => { "uri" => "file:///test.trb" },
        "position" => { "line" => 0, "character" => 11 } # On "Printable"
      })

      expect(response["result"]["contents"]["value"]).to include("Interface")
      expect(response["result"]["contents"]["value"]).to include("Printable")
    end

    it "returns nil for unknown words" do
      send_notification("textDocument/didOpen", {
        "textDocument" => {
          "uri" => "file:///test.trb",
          "version" => 1,
          "text" => "unknown_symbol"
        }
      })

      response = send_request("textDocument/hover", {
        "textDocument" => { "uri" => "file:///test.trb" },
        "position" => { "line" => 0, "character" => 5 }
      })

      expect(response["result"]).to be_nil
    end
  end

  describe "textDocument/definition" do
    before do
      send_request("initialize", {})
    end

    it "finds type alias definition" do
      send_notification("textDocument/didOpen", {
        "textDocument" => {
          "uri" => "file:///test.trb",
          "version" => 1,
          "text" => "type UserId = String\ndef get(id: UserId): String\nend"
        }
      })

      response = send_request("textDocument/definition", {
        "textDocument" => { "uri" => "file:///test.trb" },
        "position" => { "line" => 1, "character" => 13 } # On "UserId"
      })

      expect(response["result"]["uri"]).to eq("file:///test.trb")
      expect(response["result"]["range"]["start"]["line"]).to eq(0)
    end

    it "finds interface definition" do
      send_notification("textDocument/didOpen", {
        "textDocument" => {
          "uri" => "file:///test.trb",
          "version" => 1,
          "text" => "interface Readable\n  read: String\nend\ndef process(r: Readable): void\nend"
        }
      })

      response = send_request("textDocument/definition", {
        "textDocument" => { "uri" => "file:///test.trb" },
        "position" => { "line" => 3, "character" => 17 } # On "Readable"
      })

      expect(response["result"]["uri"]).to eq("file:///test.trb")
      expect(response["result"]["range"]["start"]["line"]).to eq(0)
    end

    it "finds function definition" do
      send_notification("textDocument/didOpen", {
        "textDocument" => {
          "uri" => "file:///test.trb",
          "version" => 1,
          "text" => "def helper(): String\n  \"help\"\nend\ndef main(): void\n  helper()\nend"
        }
      })

      response = send_request("textDocument/definition", {
        "textDocument" => { "uri" => "file:///test.trb" },
        "position" => { "line" => 4, "character" => 3 } # On "helper"
      })

      expect(response["result"]["uri"]).to eq("file:///test.trb")
      expect(response["result"]["range"]["start"]["line"]).to eq(0)
    end
  end

  describe "diagnostics" do
    before do
      send_request("initialize", {})
    end

    it "publishes diagnostics on document open" do
      send_notification("textDocument/didOpen", {
        "textDocument" => {
          "uri" => "file:///test.trb",
          "version" => 1,
          "text" => "def test(name: UnknownType): String\nend"
        }
      })

      # Check that diagnostics were published
      output.rewind
      response_text = output.read

      expect(response_text).to include("publishDiagnostics")
    end

    it "detects duplicate function definitions" do
      send_notification("textDocument/didOpen", {
        "textDocument" => {
          "uri" => "file:///test.trb",
          "version" => 1,
          "text" => "def hello(): void\nend\ndef hello(): void\nend"
        }
      })

      output.rewind
      response_text = output.read

      expect(response_text).to include("already defined")
    end

    it "detects invalid parameter syntax" do
      send_notification("textDocument/didOpen", {
        "textDocument" => {
          "uri" => "file:///test.trb",
          "version" => 1,
          "text" => "def test(: String): void\nend"
        }
      })

      output.rewind
      response_text = output.read

      expect(response_text).to include("Invalid parameter syntax")
    end

    it "clears diagnostics on document close" do
      send_notification("textDocument/didOpen", {
        "textDocument" => {
          "uri" => "file:///test.trb",
          "version" => 1,
          "text" => "def hello(): void\nend"
        }
      })

      # Create a new output buffer to capture close notification
      new_output = StringIO.new
      new_output.set_encoding("UTF-8")
      server.instance_variable_set(:@output, new_output)

      send_notification("textDocument/didClose", {
        "textDocument" => { "uri" => "file:///test.trb" }
      })

      new_output.rewind
      response_text = new_output.read

      expect(response_text).to include("publishDiagnostics")
      expect(response_text).to include('"diagnostics":[]')
    end
  end

  describe "error handling" do
    before { send_request("initialize", {}) }

    it "returns method not found for unknown methods" do
      response = send_request("unknownMethod", {})

      expect(response["error"]["code"]).to eq(TRuby::LSPServer::ErrorCodes::METHOD_NOT_FOUND)
      expect(response["error"]["message"]).to include("unknownMethod")
    end

    it "handles malformed JSON gracefully" do
      input.string = "Content-Length: 10\r\n\r\n{invalid}"
      input.rewind

      message = server.read_message
      expect(message).to have_key("error")
    end
  end

  describe "response format" do
    before { send_request("initialize", {}) }

    it "includes jsonrpc version in responses" do
      response = send_request("shutdown")

      expect(response["jsonrpc"]).to eq("2.0")
    end

    it "includes request id in responses" do
      response = send_request("shutdown", {}, id: 42)

      expect(response["id"]).to eq(42)
    end
  end
end
