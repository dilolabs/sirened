require "socket"

class FakeHTTPServer
  def initialize(&script)
    @script = script
    @server = TCPServer.new("127.0.0.1", 0)
    @thread = Thread.new { serve }
  end

  def port
    @server.addr[1]
  end

  def url(path)
    "http://127.0.0.1:#{port}#{path}"
  end

  def shutdown
    @server.close unless @server.closed?
    Thread.kill(@thread)
  rescue StandardError
    nil
  end

  private

  def serve
    loop do
      client = @server.accept
      handle(client)
    end
  rescue IOError, Errno::EBADF
    nil
  end

  def handle(client)
    request_line = client.gets.to_s
    method, path = request_line.split(" ")
    while (line = client.gets) && line != "\r\n"
    end

    status, extra_headers, body = @script.call(method, path.to_s)

    payload = +"HTTP/1.1 #{status}\r\n"
    extra_headers.each { |key, value| payload << "#{key}: #{value}\r\n" }
    payload << "Content-Length: #{body.to_s.bytesize}\r\n"
    payload << "Connection: close\r\n"
    payload << "\r\n"
    payload << body.to_s
    client.write(payload)
  ensure
    client.close rescue nil
  end
end
