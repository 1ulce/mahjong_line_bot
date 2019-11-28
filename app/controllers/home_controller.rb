class HomeController < ApplicationController
  protect_from_forgery :except => [:callback]
  
  def show
  end

  def line_callback
    body = request.body.read
    events = line_client.parse_events_from(body)
    events.each do |event|
      case event
      when Line::Bot::Event::Message
        case event.type
        when Line::Bot::Event::MessageType::Text
          text = event.message['text'].gsub("@"+ENV["LINE_NAME"],"<@"+ENV["SLACK_YOUR_ID"]+">")
          message = {
            type: 'text',
            text: text
          }
          user_name, user_icon_url = get_display_name(event['source']['userId'])
          #p user_name
          slack_client.chat_postMessage(channel: "#"+ENV["SLACK_CHANNEL_NAME"], text: text, as_user: false, username: user_name, icon_url: user_icon_url) if text
          
        when Line::Bot::Event::MessageType::Image, Line::Bot::Event::MessageType::Video
          user_name, user_icon_url = get_display_name(event['source']['userId'])
          text = "[system]#{user_name}がなんかの画像を投稿しました"
          message = {
            type: 'text',
            text: text
          }
          slack_client.chat_postMessage(channel: "#"+ENV["SLACK_CHANNEL_NAME"], text: text, as_user: false)
          
        end
      end
    end
    head :ok
  end

  def slack_callback
    @body = JSON.parse(request.body.read)
    case @body['type']
    when 'url_verification'
      render json: @body
    when 'event_callback'
      unless @body['event']['subtype'] == "bot_message"
        if @body['event']['subtype'] == "file_share"
          file = @body['event']['files'][0]
          fetch_and_save_image(file)
          image_url = "https://#{ENV["NGROK_DOMAIN"]}.ngrok.io/uploads/#{file['id']}"
          message = {
            type: "image",
            originalContentUrl: image_url,
            previewImageUrl: image_url
          }
          #line_client.push_message(ENV["LINE_IMAGE_GROUP"], message)
          system("osascript line_paste.scpt")
          head :ok
        else
          p @body['event']['channel']
          text = @body['event']['text']
          message = {
            type: 'text',
            text: text
          }
          #line_client.push_message(ENV["LINE_MESSAGE_GROUP"], message)
          system("echo '#{text}' | pbcopy")
          system("osascript line_paste.scpt")
          head :ok
        end
      end
    end
  end

  private

  def fetch_and_save_image(file)
    File.open("public/uploads/#{file['id']}.#{file['filetype']}", 'wb') do |f|
      res = RestClient.get(file['url_private'], { "Authorization" => "Bearer #{ENV['SLACK_TOKEN']}" })
      if res.code == 200
        f << res.body
      end
    end
    system("osascript image_copy.scpt #{Rails.root}/public/uploads/#{file['id']}.#{file['filetype']}")
  end

  def get_display_name(userId)
    response = line_client.get_profile(userId)
    case response
    when Net::HTTPSuccess then
      contact = JSON.parse(response.body)
      #p contact['displayName']
      #p contact['pictureUrl']
      #p contact['statusMessage']
      return [contact['displayName'],contact['pictureUrl']]
    else
      p "#{response.code} #{response.body}"
    end
  end
end
