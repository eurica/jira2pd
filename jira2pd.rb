require 'sinatra'
require 'pp'
require "json"
require 'httparty'

set :logging, true

get '/' do
  puts "Get"
  ProcessWebhook.jira request
end

post '/' do
  puts "Posted"
  ProcessWebhook.jira request
end

post '/jira/:service_key' do
  puts "Posted to #{params[:service_key]}"
  pp request[:service_key]
  ProcessWebhook.jira request
end


class ProcessWebhook
  def self.jira(request)
    pp request
    request.body.rewind
    request_payload = request.body.read
    
    begin
      wh = JSON.parse(request_payload)
    rescue
      return "Failed to parse json"
    end

    incident_key = wh["issue"]["key"]
    puts incident_key
    incident_description = wh["issue"]["fields"]["description"] || incident_key
    puts incident_description
    client_url = wh["issue"]["self"].gsub(/rest\/api.+/, "browse/#{incident_key}")
    puts client_url

    service_key = request["service_key"] || '20a7358fe06849dab725cd2e665e0c03'
    puts service_key
    details = {}
    details["priority"] = wh["issue"]["fields"]["priority"]["name"] || ""
    details["assignee"] = (wh["issue"]["fields"]["assignee"]["displayName"] || "") if wh["issue"]["fields"]["assignee"]
    details["status"] = wh["issue"]["fields"]["status"]["name"] || ""
    details["issuetype"] = wh["issue"]["fields"]["issuetype"]["name"] || ""
    details["description"] = wh["issue"]["fields"]["description"] if wh["issue"]["fields"]["description"]
    
    incident_description = "#{wh['issue']['fields']['summary']} (#{incident_key})" || incident_key
    event_type = "trigger"
    event_type = "resolve" if wh["issue"]["fields"]["status"]["statusCategory"]['key'] == "done"
    # 'done' is a constant https://docs.atlassian.com/jira/6.2.1/constant-values.html#com.atlassian.jira.issue.status.category.StatusCategory.COMPLETE
    event_type = "acknowledge" if wh["issue"]["fields"]["status"]["name"] == "In Development"
    # Could be statusCategory = indeterminate
    puts "#{details["status"]} = #{event_type}"
    
    
    
    result = HTTParty.post("https://events.pagerduty.com/generic/2010-04-15/create_event.json", 
        body: { service_key: service_key, 
          description: incident_description,
          incident_key: incident_key,
          event_type: event_type,
          details: details,
          client: "JIRA",
          client_url: client_url
          }.to_json,
        headers: { 'Content-Type' => 'application/json' } )


    
    
    result.body
  end
end