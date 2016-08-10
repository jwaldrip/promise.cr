require "../src/promise"
require "http/client"
require "json"

def read_body(response : HTTP::Client::Response) : String
  response.body
end

request = Promise(HTTP::Client::Response | JSON::Any).execute do
  HTTP::Client.get "https://httpbin.org/user-agent"
end

puts "do something else...."

request.then do |response|
  JSON.parse(read_body(response.as(HTTP::Client::Response)))
end.catch do |ex|
  puts "caught!"
  puts ex.message
end.then do |json_hash|
  puts json_hash
end.await
