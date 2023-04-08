require 'socket'
require_relative 'http_server'

http_server = HttpServer.new

server = TCPServer.new(8080)
loop do
  Thread.start(server.accept) do |client|
    http_server.process(client)
  end
end
