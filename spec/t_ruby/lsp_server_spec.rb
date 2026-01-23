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
      "params" => params,
    }
    input.string = create_message(message)
    input.rewind

    server.handle_message(server.read_message)
  end

  # Helper to send notification (no id)
  def send_notification(method, params = {})
    message = {
      "jsonrpc" => "2.0",
      "method" => method,
      "params" => params,
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
                                "capabilities" => {},
                              })

      expect(response["result"]["capabilities"]).to include(
        "textDocumentSync" => hash_including("openClose" => true),
        "completionProvider" => hash_including("triggerCharacters" => [":", "<", "|", "&"]),
        "hoverProvider" => true,
        "definitionProvider" => true
      )
    end

    it "returns server info" do
      response = send_request("initialize", {})

      expect(response["result"]["serverInfo"]).to eq({
                                                       "name" => "t-ruby-lsp",
                                                       "version" => TRuby::LSPServer::VERSION,
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
                            "text" => "def hello(name: String): String\nend",
                          },
                        })

      # Verify document was stored by checking hover works
      response = send_request("textDocument/hover", {
                                "textDocument" => { "uri" => "file:///test.trb" },
                                "position" => { "line" => 0, "character" => 4 },
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
                            "text" => "def old(): void\nend",
                          },
                        })
    end

    it "updates document content" do
      send_notification("textDocument/didChange", {
                          "textDocument" => { "uri" => "file:///test.trb", "version" => 2 },
                          "contentChanges" => [{ "text" => "def new_function(): String\nend" }],
                        })

      response = send_request("textDocument/hover", {
                                "textDocument" => { "uri" => "file:///test.trb" },
                                "position" => { "line" => 0, "character" => 4 },
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
                            "text" => "def hello(): void\nend",
                          },
                        })
    end

    it "removes document from storage" do
      send_notification("textDocument/didClose", {
                          "textDocument" => { "uri" => "file:///test.trb" },
                        })

      response = send_request("textDocument/hover", {
                                "textDocument" => { "uri" => "file:///test.trb" },
                                "position" => { "line" => 0, "character" => 0 },
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
                            "text" => "type UserId = String\ndef get_user(id: ): UserId\nend",
                          },
                        })
    end

    it "provides built-in type completions after colon" do
      response = send_request("textDocument/completion", {
                                "textDocument" => { "uri" => "file:///test.trb" },
                                "position" => { "line" => 1, "character" => 17 }, # After "id: "
                              })

      items = response["result"]["items"]
      labels = items.map { |i| i["label"] }

      expect(labels).to include("String", "Integer", "Boolean", "Array", "Hash")
    end

    it "includes type aliases in completions" do
      response = send_request("textDocument/completion", {
                                "textDocument" => { "uri" => "file:///test.trb" },
                                "position" => { "line" => 1, "character" => 17 },
                              })

      items = response["result"]["items"]
      labels = items.map { |i| i["label"] }

      expect(labels).to include("UserId")
    end

    it "provides keyword completions at line start" do
      send_notification("textDocument/didChange", {
                          "textDocument" => { "uri" => "file:///test.trb", "version" => 2 },
                          "contentChanges" => [{ "text" => "" }],
                        })

      response = send_request("textDocument/completion", {
                                "textDocument" => { "uri" => "file:///test.trb" },
                                "position" => { "line" => 0, "character" => 0 },
                              })

      items = response["result"]["items"]
      labels = items.map { |i| i["label"] }

      expect(labels).to include("type", "interface", "def", "end")
    end

    it "provides tuple type completions" do
      response = send_request("textDocument/completion", {
                                "textDocument" => { "uri" => "file:///test.trb" },
                                "position" => { "line" => 1, "character" => 17 },
                              })

      items = response["result"]["items"]
      labels = items.map { |i| i["label"] }

      expect(labels).to include("[T, U]", "[T, *U[]]")
    end

    it "provides tuple completion with snippet format" do
      response = send_request("textDocument/completion", {
                                "textDocument" => { "uri" => "file:///test.trb" },
                                "position" => { "line" => 1, "character" => 17 },
                              })

      items = response["result"]["items"]
      tuple_item = items.find { |i| i["label"] == "[T, U]" }

      expect(tuple_item).not_to be_nil
      expect(tuple_item["detail"]).to eq("Tuple type")
      expect(tuple_item["insertText"]).to eq("[${1:Type}, ${2:Type}]")
      expect(tuple_item["insertTextFormat"]).to eq(2) # Snippet format
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
                            "text" => "def test(name: String): Integer\nend",
                          },
                        })

      response = send_request("textDocument/hover", {
                                "textDocument" => { "uri" => "file:///test.trb" },
                                "position" => { "line" => 0, "character" => 16 }, # On "String"
                              })

      expect(response["result"]["contents"]["value"]).to include("String")
      expect(response["result"]["contents"]["value"]).to include("Built-in")
    end

    it "shows hover info for type aliases" do
      send_notification("textDocument/didOpen", {
                          "textDocument" => {
                            "uri" => "file:///test.trb",
                            "version" => 1,
                            "text" => "type UserId = String\ndef get(id: UserId): String\nend",
                          },
                        })

      response = send_request("textDocument/hover", {
                                "textDocument" => { "uri" => "file:///test.trb" },
                                "position" => { "line" => 0, "character" => 6 }, # On "UserId"
                              })

      expect(response["result"]["contents"]["value"]).to include("Type Alias")
      expect(response["result"]["contents"]["value"]).to include("UserId")
    end

    it "shows hover info for functions" do
      send_notification("textDocument/didOpen", {
                          "textDocument" => {
                            "uri" => "file:///test.trb",
                            "version" => 1,
                            "text" => "def greet(name: String): String\n  \"Hello\"\nend",
                          },
                        })

      response = send_request("textDocument/hover", {
                                "textDocument" => { "uri" => "file:///test.trb" },
                                "position" => { "line" => 0, "character" => 5 }, # On "greet"
                              })

      expect(response["result"]["contents"]["value"]).to include("Function")
      expect(response["result"]["contents"]["value"]).to include("greet")
    end

    it "shows hover info for interfaces" do
      send_notification("textDocument/didOpen", {
                          "textDocument" => {
                            "uri" => "file:///test.trb",
                            "version" => 1,
                            "text" => "interface Printable\n  to_string: String\nend",
                          },
                        })

      response = send_request("textDocument/hover", {
                                "textDocument" => { "uri" => "file:///test.trb" },
                                "position" => { "line" => 0, "character" => 11 }, # On "Printable"
                              })

      expect(response["result"]["contents"]["value"]).to include("Interface")
      expect(response["result"]["contents"]["value"]).to include("Printable")
    end

    it "returns nil for unknown words" do
      send_notification("textDocument/didOpen", {
                          "textDocument" => {
                            "uri" => "file:///test.trb",
                            "version" => 1,
                            "text" => "unknown_symbol",
                          },
                        })

      response = send_request("textDocument/hover", {
                                "textDocument" => { "uri" => "file:///test.trb" },
                                "position" => { "line" => 0, "character" => 5 },
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
                            "text" => "type UserId = String\ndef get(id: UserId): String\nend",
                          },
                        })

      response = send_request("textDocument/definition", {
                                "textDocument" => { "uri" => "file:///test.trb" },
                                "position" => { "line" => 1, "character" => 13 }, # On "UserId"
                              })

      expect(response["result"]["uri"]).to eq("file:///test.trb")
      expect(response["result"]["range"]["start"]["line"]).to eq(0)
    end

    it "finds interface definition" do
      send_notification("textDocument/didOpen", {
                          "textDocument" => {
                            "uri" => "file:///test.trb",
                            "version" => 1,
                            "text" => "interface Readable\n  read: String\nend\ndef process(r: Readable): void\nend",
                          },
                        })

      response = send_request("textDocument/definition", {
                                "textDocument" => { "uri" => "file:///test.trb" },
                                "position" => { "line" => 3, "character" => 17 }, # On "Readable"
                              })

      expect(response["result"]["uri"]).to eq("file:///test.trb")
      expect(response["result"]["range"]["start"]["line"]).to eq(0)
    end

    it "finds function definition" do
      send_notification("textDocument/didOpen", {
                          "textDocument" => {
                            "uri" => "file:///test.trb",
                            "version" => 1,
                            "text" => "def helper(): String\n  \"help\"\nend\ndef main(): void\n  helper()\nend",
                          },
                        })

      response = send_request("textDocument/definition", {
                                "textDocument" => { "uri" => "file:///test.trb" },
                                "position" => { "line" => 4, "character" => 3 }, # On "helper"
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
                            "text" => "def test(name: UnknownType): String\nend",
                          },
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
                            "text" => "def hello(): void\nend\ndef hello(): void\nend",
                          },
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
                            "text" => "def test(: String): void\nend",
                          },
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
                            "text" => "def hello(): void\nend",
                          },
                        })

      # Create a new output buffer to capture close notification
      new_output = StringIO.new
      new_output.set_encoding("UTF-8")
      server.instance_variable_set(:@output, new_output)

      send_notification("textDocument/didClose", {
                          "textDocument" => { "uri" => "file:///test.trb" },
                        })

      new_output.rewind
      response_text = new_output.read

      expect(response_text).to include("publishDiagnostics")
      expect(response_text).to include('"diagnostics":[]')
    end

    it "responds to pull-based diagnostic requests" do
      send_notification("textDocument/didOpen", {
                          "textDocument" => {
                            "uri" => "file:///test.trb",
                            "version" => 1,
                            "text" => "def test(name: UnknownType): String\nend",
                          },
                        })

      response = send_request("textDocument/diagnostic", {
                                "textDocument" => { "uri" => "file:///test.trb" },
                              })

      expect(response["result"]["kind"]).to eq("full")
      expect(response["result"]["items"]).to be_an(Array)
      expect(response["result"]["items"].length).to be > 0
    end

    it "returns empty diagnostics for valid code via pull request" do
      send_notification("textDocument/didOpen", {
                          "textDocument" => {
                            "uri" => "file:///valid.trb",
                            "version" => 1,
                            "text" => "def greet(name: String): String\n  name\nend",
                          },
                        })

      response = send_request("textDocument/diagnostic", {
                                "textDocument" => { "uri" => "file:///valid.trb" },
                              })

      expect(response["result"]["kind"]).to eq("full")
      expect(response["result"]["items"]).to eq([])
    end

    it "returns empty diagnostics for unknown document" do
      response = send_request("textDocument/diagnostic", {
                                "textDocument" => { "uri" => "file:///unknown.trb" },
                              })

      expect(response["result"]["kind"]).to eq("full")
      expect(response["result"]["items"]).to eq([])
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

  describe "textDocument/semanticTokens/full" do
    before do
      send_request("initialize", {})
    end

    it "returns semantic tokens for type aliases" do
      send_notification("textDocument/didOpen", {
                          "textDocument" => {
                            "uri" => "file:///test.trb",
                            "version" => 1,
                            "text" => "type UserId = String",
                          },
                        })

      response = send_request("textDocument/semanticTokens/full", {
                                "textDocument" => { "uri" => "file:///test.trb" },
                              })

      expect(response["result"]["data"]).to be_an(Array)
    end

    it "returns semantic tokens for interfaces" do
      send_notification("textDocument/didOpen", {
                          "textDocument" => {
                            "uri" => "file:///test.trb",
                            "version" => 1,
                            "text" => "interface Printable\n  to_s: String\nend",
                          },
                        })

      response = send_request("textDocument/semanticTokens/full", {
                                "textDocument" => { "uri" => "file:///test.trb" },
                              })

      expect(response["result"]["data"]).to be_an(Array)
    end

    it "returns semantic tokens for functions" do
      send_notification("textDocument/didOpen", {
                          "textDocument" => {
                            "uri" => "file:///test.trb",
                            "version" => 1,
                            "text" => "def greet(name: String): void\n  puts name\nend",
                          },
                        })

      response = send_request("textDocument/semanticTokens/full", {
                                "textDocument" => { "uri" => "file:///test.trb" },
                              })

      expect(response["result"]["data"]).to be_an(Array)
    end

    it "returns empty data for unknown document" do
      response = send_request("textDocument/semanticTokens/full", {
                                "textDocument" => { "uri" => "file:///unknown.trb" },
                              })

      expect(response["result"]["data"]).to eq([])
    end
  end

  describe "completion contexts" do
    before do
      send_request("initialize", {})
    end

    it "provides completions after pipe for union types" do
      send_notification("textDocument/didOpen", {
                          "textDocument" => {
                            "uri" => "file:///test.trb",
                            "version" => 1,
                            "text" => "def test(x: String | ): void\nend",
                          },
                        })

      response = send_request("textDocument/completion", {
                                "textDocument" => { "uri" => "file:///test.trb" },
                                "position" => { "line" => 0, "character" => 21 },
                              })

      items = response["result"]["items"]
      expect(items).not_to be_empty
    end

    it "provides completions after ampersand for intersection types" do
      send_notification("textDocument/didOpen", {
                          "textDocument" => {
                            "uri" => "file:///test.trb",
                            "version" => 1,
                            "text" => "def test(x: Readable & ): void\nend",
                          },
                        })

      response = send_request("textDocument/completion", {
                                "textDocument" => { "uri" => "file:///test.trb" },
                                "position" => { "line" => 0, "character" => 23 },
                              })

      items = response["result"]["items"]
      expect(items).not_to be_empty
    end

    it "provides completions after generic bracket" do
      send_notification("textDocument/didOpen", {
                          "textDocument" => {
                            "uri" => "file:///test.trb",
                            "version" => 1,
                            "text" => "def test(x: Array< ): void\nend",
                          },
                        })

      response = send_request("textDocument/completion", {
                                "textDocument" => { "uri" => "file:///test.trb" },
                                "position" => { "line" => 0, "character" => 19 },
                              })

      items = response["result"]["items"]
      expect(items).not_to be_empty
    end

    it "provides no completions during def name" do
      send_notification("textDocument/didOpen", {
                          "textDocument" => {
                            "uri" => "file:///test.trb",
                            "version" => 1,
                            "text" => "def mymethod",
                          },
                        })

      response = send_request("textDocument/completion", {
                                "textDocument" => { "uri" => "file:///test.trb" },
                                "position" => { "line" => 0, "character" => 12 },
                              })

      items = response["result"]["items"]
      labels = items.map { |i| i["label"] }
      # Should not include standard type completions during def naming
      expect(labels).not_to include("type", "interface")
    end

    it "provides interface completions from document" do
      send_notification("textDocument/didOpen", {
                          "textDocument" => {
                            "uri" => "file:///test.trb",
                            "version" => 1,
                            "text" => "interface Readable\n  read: String\nend\ndef test(r: ): void\nend",
                          },
                        })

      response = send_request("textDocument/completion", {
                                "textDocument" => { "uri" => "file:///test.trb" },
                                "position" => { "line" => 3, "character" => 13 },
                              })

      items = response["result"]["items"]
      labels = items.map { |i| i["label"] }
      expect(labels).to include("Readable")
    end

    it "returns empty for unknown document" do
      response = send_request("textDocument/completion", {
                                "textDocument" => { "uri" => "file:///unknown.trb" },
                                "position" => { "line" => 0, "character" => 0 },
                              })

      expect(response["result"]["items"]).to eq([])
    end
  end

  describe "hover edge cases" do
    before { send_request("initialize", {}) }

    it "returns nil for empty line" do
      send_notification("textDocument/didOpen", {
                          "textDocument" => {
                            "uri" => "file:///test.trb",
                            "version" => 1,
                            "text" => "\n\n\n",
                          },
                        })

      response = send_request("textDocument/hover", {
                                "textDocument" => { "uri" => "file:///test.trb" },
                                "position" => { "line" => 1, "character" => 0 },
                              })

      expect(response["result"]).to be_nil
    end

    it "returns nil for position beyond line length" do
      send_notification("textDocument/didOpen", {
                          "textDocument" => {
                            "uri" => "file:///test.trb",
                            "version" => 1,
                            "text" => "def test",
                          },
                        })

      response = send_request("textDocument/hover", {
                                "textDocument" => { "uri" => "file:///test.trb" },
                                "position" => { "line" => 0, "character" => 100 },
                              })

      expect(response["result"]).to be_nil
    end

    it "shows interface members in hover" do
      send_notification("textDocument/didOpen", {
                          "textDocument" => {
                            "uri" => "file:///test.trb",
                            "version" => 1,
                            "text" => "interface Runnable\n  run: void\n  stop: void\nend",
                          },
                        })

      response = send_request("textDocument/hover", {
                                "textDocument" => { "uri" => "file:///test.trb" },
                                "position" => { "line" => 0, "character" => 11 },
                              })

      expect(response["result"]["contents"]["value"]).to include("Interface")
      expect(response["result"]["contents"]["value"]).to include("Runnable")
    end
  end

  describe "definition edge cases" do
    before { send_request("initialize", {}) }

    it "returns nil for unknown document" do
      response = send_request("textDocument/definition", {
                                "textDocument" => { "uri" => "file:///unknown.trb" },
                                "position" => { "line" => 0, "character" => 0 },
                              })

      expect(response["result"]).to be_nil
    end

    it "returns nil for undefined symbol" do
      send_notification("textDocument/didOpen", {
                          "textDocument" => {
                            "uri" => "file:///test.trb",
                            "version" => 1,
                            "text" => "unknown_symbol",
                          },
                        })

      response = send_request("textDocument/definition", {
                                "textDocument" => { "uri" => "file:///test.trb" },
                                "position" => { "line" => 0, "character" => 5 },
                              })

      expect(response["result"]).to be_nil
    end

    it "returns nil for empty word" do
      send_notification("textDocument/didOpen", {
                          "textDocument" => {
                            "uri" => "file:///test.trb",
                            "version" => 1,
                            "text" => "   ",
                          },
                        })

      response = send_request("textDocument/definition", {
                                "textDocument" => { "uri" => "file:///test.trb" },
                                "position" => { "line" => 0, "character" => 1 },
                              })

      expect(response["result"]).to be_nil
    end
  end

  describe "LSP constants" do
    it "defines VERSION" do
      expect(TRuby::LSPServer::VERSION).to be_a(String)
    end

    it "defines error codes" do
      expect(TRuby::LSPServer::ErrorCodes::PARSE_ERROR).to eq(-32_700)
      expect(TRuby::LSPServer::ErrorCodes::INVALID_REQUEST).to eq(-32_600)
      expect(TRuby::LSPServer::ErrorCodes::METHOD_NOT_FOUND).to eq(-32_601)
      expect(TRuby::LSPServer::ErrorCodes::INVALID_PARAMS).to eq(-32_602)
      expect(TRuby::LSPServer::ErrorCodes::INTERNAL_ERROR).to eq(-32_603)
      expect(TRuby::LSPServer::ErrorCodes::SERVER_NOT_INITIALIZED).to eq(-32_002)
      expect(TRuby::LSPServer::ErrorCodes::UNKNOWN_ERROR_CODE).to eq(-32_001)
    end

    it "defines completion item kinds" do
      expect(TRuby::LSPServer::CompletionItemKind::CLASS).to eq(7)
      expect(TRuby::LSPServer::CompletionItemKind::INTERFACE).to eq(8)
      expect(TRuby::LSPServer::CompletionItemKind::KEYWORD).to eq(14)
      expect(TRuby::LSPServer::CompletionItemKind::FUNCTION).to eq(3)
    end

    it "defines diagnostic severity" do
      expect(TRuby::LSPServer::DiagnosticSeverity::ERROR).to eq(1)
      expect(TRuby::LSPServer::DiagnosticSeverity::WARNING).to eq(2)
      expect(TRuby::LSPServer::DiagnosticSeverity::INFORMATION).to eq(3)
      expect(TRuby::LSPServer::DiagnosticSeverity::HINT).to eq(4)
    end

    it "defines semantic token types" do
      expect(TRuby::LSPServer::SemanticTokenTypes::TYPE).to eq(1)
      expect(TRuby::LSPServer::SemanticTokenTypes::INTERFACE).to eq(4)
      expect(TRuby::LSPServer::SemanticTokenTypes::FUNCTION).to eq(12)
      expect(TRuby::LSPServer::SemanticTokenTypes::KEYWORD).to eq(15)
    end

    it "defines semantic token modifiers" do
      expect(TRuby::LSPServer::SemanticTokenModifiers::DECLARATION).to eq(0x01)
      expect(TRuby::LSPServer::SemanticTokenModifiers::DEFINITION).to eq(0x02)
      expect(TRuby::LSPServer::SemanticTokenModifiers::DEFAULT_LIBRARY).to eq(0x200)
    end

    it "defines built-in types list" do
      expect(TRuby::LSPServer::BUILT_IN_TYPES).to include("String", "Integer", "Boolean")
    end

    it "defines type keywords list" do
      expect(TRuby::LSPServer::TYPE_KEYWORDS).to include("type", "interface", "def", "end")
    end

    it "defines semantic token type names" do
      expect(TRuby::LSPServer::SEMANTIC_TOKEN_TYPES).to include("type", "interface", "function", "keyword")
    end

    it "defines semantic token modifier names" do
      expect(TRuby::LSPServer::SEMANTIC_TOKEN_MODIFIERS).to include("declaration", "definition", "defaultLibrary")
    end
  end

  describe "send_notification" do
    it "sends notification without id" do
      server.send(:send_notification, "window/logMessage", { "message" => "test" })

      output.rewind
      response_text = output.read

      expect(response_text).to include("window/logMessage")
      expect(response_text).not_to include('"id"')
    end
  end

  describe "uri_to_path" do
    it "converts file URI to path" do
      path = server.send(:uri_to_path, "file:///Users/test/project/test.trb")
      expect(path).to eq("/Users/test/project/test.trb")
    end

    it "returns non-file URIs unchanged" do
      uri = "https://example.com/test"
      expect(server.send(:uri_to_path, uri)).to eq(uri)
    end
  end

  describe "create_diagnostic" do
    it "creates LSP diagnostic format" do
      diagnostic = server.send(:create_diagnostic, 5, "Test error", TRuby::LSPServer::DiagnosticSeverity::ERROR)

      expect(diagnostic["range"]["start"]["line"]).to eq(5)
      expect(diagnostic["message"]).to eq("Test error")
      expect(diagnostic["severity"]).to eq(1)
      expect(diagnostic["source"]).to eq("t-ruby")
    end
  end

  describe "keyword_documentation" do
    it "provides documentation for type keyword" do
      doc = server.send(:keyword_documentation, "type")
      expect(doc).to include("type alias")
    end

    it "provides documentation for interface keyword" do
      doc = server.send(:keyword_documentation, "interface")
      expect(doc).to include("interface")
    end

    it "provides documentation for def keyword" do
      doc = server.send(:keyword_documentation, "def")
      expect(doc).to include("function")
    end

    it "provides documentation for end keyword" do
      doc = server.send(:keyword_documentation, "end")
      expect(doc).to include("End")
    end

    it "returns keyword itself for unknown" do
      doc = server.send(:keyword_documentation, "unknown")
      expect(doc).to eq("unknown")
    end
  end

  describe "extract_word_at_position" do
    it "extracts word at cursor" do
      line = "def hello"
      word = server.send(:extract_word_at_position, line, 5)
      expect(word).to eq("hello")
    end

    it "returns nil for position beyond line" do
      line = "short"
      word = server.send(:extract_word_at_position, line, 100)
      expect(word).to be_nil
    end

    it "handles generic types with brackets" do
      line = "Array<String>"
      word = server.send(:extract_word_at_position, line, 0)
      expect(word).to include("Array")
    end
  end

  describe "word_range" do
    it "calculates word range" do
      range = server.send(:word_range, 10, "def hello", 5, "hello")

      expect(range["start"]["line"]).to eq(10)
      expect(range["end"]["line"]).to eq(10)
    end
  end

  describe "diagnostic_to_lsp" do
    it "converts TRuby diagnostic to LSP format" do
      diagnostic = TRuby::Diagnostic.new(
        code: "TR0001",
        message: "Test error",
        file: "test.trb",
        line: 10,
        column: 5,
        severity: :error
      )

      lsp_diag = server.send(:diagnostic_to_lsp, diagnostic)

      expect(lsp_diag["range"]["start"]["line"]).to eq(9) # 0-based
      expect(lsp_diag["range"]["start"]["character"]).to eq(4) # 0-based
      expect(lsp_diag["severity"]).to eq(TRuby::LSPServer::DiagnosticSeverity::ERROR)
      expect(lsp_diag["code"]).to eq("TR0001")
    end

    it "handles warning severity" do
      diagnostic = TRuby::Diagnostic.new(
        code: "TR0002",
        message: "Warning",
        file: "test.trb",
        line: 1,
        column: 1,
        severity: :warning
      )

      lsp_diag = server.send(:diagnostic_to_lsp, diagnostic)
      expect(lsp_diag["severity"]).to eq(TRuby::LSPServer::DiagnosticSeverity::WARNING)
    end

    it "handles info severity" do
      diagnostic = TRuby::Diagnostic.new(
        code: "TR0003",
        message: "Info",
        file: "test.trb",
        line: 1,
        column: 1,
        severity: :info
      )

      lsp_diag = server.send(:diagnostic_to_lsp, diagnostic)
      expect(lsp_diag["severity"]).to eq(TRuby::LSPServer::DiagnosticSeverity::INFORMATION)
    end

    it "handles negative line numbers" do
      diagnostic = TRuby::Diagnostic.new(
        code: "TR0001",
        message: "Error",
        file: "test.trb",
        line: -1,
        column: -1,
        severity: :error
      )

      lsp_diag = server.send(:diagnostic_to_lsp, diagnostic)
      expect(lsp_diag["range"]["start"]["line"]).to eq(0)
      expect(lsp_diag["range"]["start"]["character"]).to eq(0)
    end
  end

  describe "analyze_document" do
    it "analyzes document and returns diagnostics" do
      diagnostics = server.send(:analyze_document, "def test(: String): void\nend")
      expect(diagnostics).to be_an(Array)
    end

    it "returns empty array for valid code" do
      diagnostics = server.send(:analyze_document, "def test(name: String): void\nend")
      expect(diagnostics).to eq([])
    end
  end

  describe "encode_tokens" do
    it "encodes tokens with delta encoding" do
      raw_tokens = [
        [0, 0, 4, 15, 1],  # line 0, char 0, length 4, keyword, declaration
        [0, 5, 5, 12, 2],  # line 0, char 5, length 5, function, definition
        [1, 0, 3, 15, 0],  # line 1, char 0, length 3, keyword
      ]

      encoded = server.send(:encode_tokens, raw_tokens)

      expect(encoded).to eq([
                              0, 0, 4, 15, 1,    # First token (no delta)
                              0, 5, 5, 12, 2,    # Same line, delta char = 5
                              1, 0, 3, 15, 0,    # Next line, char resets
                            ])
    end

    it "handles empty tokens" do
      encoded = server.send(:encode_tokens, [])
      expect(encoded).to eq([])
    end
  end

  describe "add_type_tokens" do
    it "adds tokens for built-in types" do
      raw_tokens = []
      server.send(:add_type_tokens, raw_tokens, "def test(name: String)", 0, "String")

      expect(raw_tokens).not_to be_empty
    end

    it "handles generic types" do
      raw_tokens = []
      server.send(:add_type_tokens, raw_tokens, "def test(arr: Array<String>)", 0, "Array<String>")

      expect(raw_tokens).not_to be_empty
    end

    it "handles union types" do
      raw_tokens = []
      server.send(:add_type_tokens, raw_tokens, "def test(x: String | Integer)", 0, "String | Integer")

      expect(raw_tokens).not_to be_empty
    end

    it "handles intersection types" do
      raw_tokens = []
      server.send(:add_type_tokens, raw_tokens, "def test(x: A & B)", 0, "A & B")

      expect(raw_tokens).not_to be_empty
    end

    it "handles nil type string" do
      raw_tokens = []
      server.send(:add_type_tokens, raw_tokens, "def test", 0, nil)

      expect(raw_tokens).to be_empty
    end
  end

  describe "generate_semantic_tokens" do
    it "generates tokens for complete code" do
      code = <<~TRBY
        type UserId = String
        interface Printable
          print: void
        end
        def greet(name: String): void
          puts name
        end
      TRBY

      tokens = server.send(:generate_semantic_tokens, code)

      expect(tokens).to be_an(Array)
      expect(tokens.length).to be > 0
    end

    it "handles empty code" do
      tokens = server.send(:generate_semantic_tokens, "")
      expect(tokens).to eq([])
    end
  end
end
