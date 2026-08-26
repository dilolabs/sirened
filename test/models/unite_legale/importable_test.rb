require "test_helper"
require_relative "../../support/fake_http_server"

class UniteLegale::ImportableTest < ActiveSupport::TestCase
  setup do
    @tmpdir = Dir.mktmpdir
    @destination = File.join(@tmpdir, "stock.zip")
  end

  teardown do
    FileUtils.remove_entry(@tmpdir) if @tmpdir
  end

  test "ZIP_SOURCE uses the stable data.gouv.fr URL" do
    assert_not_includes UniteLegale::ZIP_SOURCE, "files.data.gouv.fr"
    assert_match(%r{\Ahttps://www\.data\.gouv\.fr/api/1/datasets/r/}, UniteLegale::ZIP_SOURCE)
  end

  test "download_stock follows redirects and writes the file" do
    payload = "fake zip content"

    server = FakeHTTPServer.new do |method, path|
      if method == "HEAD" && path == "/stable"
        ["302 Found", { "Location" => "/final" }, ""]
      elsif method == "GET" && path == "/final"
        ["200 OK", {}, payload]
      else
        ["404 Not Found", {}, ""]
      end
    end

    UniteLegale.download_stock(source: server.url("/stable"), destination: @destination)

    assert_equal payload, File.binread(@destination)
  ensure
    server&.shutdown
  end

  test "download_stock raises Download failed on HTTP error status" do
    server = FakeHTTPServer.new do
      ["404 Not Found", {}, ""]
    end

    error = assert_raises(RuntimeError) do
      UniteLegale.download_stock(source: server.url("/stable"), destination: @destination)
    end
    assert_equal "Download failed", error.message
    assert_not File.exist?(@destination)
  ensure
    server&.shutdown
  end

  test "download_stock gives up after too many redirects" do
    server = FakeHTTPServer.new do |method, path|
      if method == "HEAD"
        ["302 Found", { "Location" => "/loop" }, ""]
      else
        ["404 Not Found", {}, ""]
      end
    end

    error = assert_raises(RuntimeError) do
      UniteLegale.download_stock(source: server.url("/loop"), destination: @destination)
    end
    assert_match(/redirect/i, error.message)
  ensure
    server&.shutdown
  end
end
