require_relative 'models/users'
require 'digest'
class HttpServer
  def process(client)
    data = []

    while line = client.gets
      data << line
      break if line == "\r\n"
    end

    request = Request.new(data, client)
    response = Application.process(request)

    client.puts response.to_s
    client.close
  end
end

class Application
  class << self
    def process(request)
      path = request.path
      case path
      when '/'
        home_page(request)
      when '/news'
        news_page(request)
      when '/registration'
        registration_page(request)
      when '/login'
        login_page(request)
      end
    end

    def home_page(request)
      Response.new(200, 'hello world!')
    end

    def news_page(request)
      Response.new(200, 'news')
    end

    def registration_page(request)
      if request.method == 'GET'
        text = File.read('html/registration_form.html')
        return Response.new(200, text)
      end

      if request.method == 'POST'
        user = { id: rand(2..1000000), name: request.post['name'], pass: Digest::MD5.hexdigest(request.post['password']) }
        model = User.new
        model.create(user)
        text = File.read('html/registration.html')
        return Response.new(200, text.sub('{body}', 'everything is ok!'))
      end

      Response.new(200, 'Unknown request')
    end

    def login_page(request)
      if request.method == 'GET'
        text = File.read('html/login_form.html')
        token = request.cookies['token']

        if token && !token.empty?
          model = User.new
          users = model.get_all

          user = users.find do |u|
            original_token = Digest::MD5.hexdigest(u['name'] + u['pass'])
            token == original_token
          end

          if user
            return Response.new(200, "hello, #{user['name']}")
          end
        end
        return Response.new(200, text)
      end

      if request.method == 'POST'
        name = request.post['name']
        password = Digest::MD5.hexdigest(request.post['password'])

        model = User.new
        users = model.get_all

        user = users.find { |u| u['name'] == name && u['pass'] == password }

        result = user ? "Hello, #{user['name']}" : 'Error! user not found'
        text = File.read('html/login.html')

        token = Digest::MD5.hexdigest(name + password)
        puts 'login:', name, password, token
        cookie = "token=#{token}; Expires=Fri, 07-Jul-23 13:22:07 GMT; Domain=localhost; Path=/"
        return Response.new(200, text.sub('{body}', result), { 'set-cookie' => cookie })
      end

      Response.new(200, 'Unknown request')
    end
  end
end

class Request

  attr_reader :method, :headers, :path, :post, :cookies

  def initialize(data, client)
    parse(data, client)
  end

  private

  def parse(data, client)
    first = data.first
    parts = first.split(' ')
    @method = parts.first
    @path = parts[1]

    # headers
    headers = data[1..].select { |l| l[/:\s/] }
    @headers = headers.map do |line|
      line.split(': ', 2).map(&:strip)
    end.to_h

    # cookies
    @cookies = (@headers['Cookie'] || '').split('; ').map { |c| c.split('=', 2) }.to_h

    # post data
    content_length = (@headers['Content-Length'] || '0').to_i

    if content_length > 0
      data = client.read(content_length)
      data = data.split('&')
      @post = data.map { |l| l.split('=', 2) }.to_h
    end
  end
end


class Response
  def initialize(code, body, headers = nil)
    @body = body
    @code = code
    @headers = headers
  end

  def to_s
    headers = @headers ? @headers.map { |k, v| "#{k}: #{v}" }.join("\r\n") + "\r\n" : ''
    "HTTP/1.1 #{@code} OK\r\n#{headers}Content-Type: text/html\r\n\r\n#{@body}"
  end
end