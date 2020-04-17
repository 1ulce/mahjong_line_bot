class HomeController < ApplicationController
  protect_from_forgery :except => [:callback]
  
  def show
  end

  def line_callback
    line_message_group = ENV['LINE_MESSAGE_GROUP']
    line_image_group = ENV['LINE_IMAGE_GROUP']
    body = request.body.read
    events = line_client.parse_events_from(body)
    events.each do |event|
      case event
      when Line::Bot::Event::Message
        slack_channel_name = ""
        if event["source"]["groupId"] == line_message_group
          slack_channel_name = "#"+ENV["SLACK_MESSAGE_CHANNEL_NAME"]
        elsif event["source"]["groupId"] == line_image_group
          slack_channel_name = "#"+ENV["SLACK_IMAGE_CHANNEL_NAME"]
        elsif event["source"]["groupId"] == nil
          if event["source"]["userId"] == "Udeadbeefdeadbeefdeadbeefdeadbeef"
            head :ok
            return
          else 
            raise "グループがなくて、認証でもないよ"
          end
        else
          raise "変なグループだよ"
        end

        case event.type
        when Line::Bot::Event::MessageType::Text
          text = event.message['text'].gsub("@"+ENV["LINE_NAME"],"<@"+ENV["SLACK_YOUR_ID"]+">")
          user = LineUser.find_or_create_by(line_id: event['source']['userId'])
          user_name = user.nick_name ? user.nick_name : user.id
          random = rand(3)
          if random == 0
            p "--------------------"
            p "random = #{random}"
            p "--------------------"
            system("osascript message_group_click.scpt")
            system("osascript image_group_click.scpt")
          end
          slack_client.chat_postMessage(channel: slack_channel_name, text: text, as_user: false, username: user_name) if text
        when Line::Bot::Event::MessageType::Sticker
          text = '[スタンプ]'
          user = LineUser.find_or_create_by(line_id: event['source']['userId'])
          user_name = user.nick_name ? user.nick_name : user.id
          slack_client.chat_postMessage(channel: slack_channel_name, text: text, as_user: false, username: user_name)

        when Line::Bot::Event::MessageType::Image, Line::Bot::Event::MessageType::Video
          file_name = event.message['id']
          file_path = "public/uploads/#{file_name}.jpg"
          image_response = line_client.get_message_content(file_name)
          file = File.open(file_path, 'wb') do |f|
            f << image_response.body
          end

          user = LineUser.find_or_create_by(line_id: event['source']['userId'])
          user_name = user.nick_name ? user.nick_name : user.id
          
          slack_client.files_upload(
            channels: slack_channel_name,
            as_user: true,
            file: Faraday::UploadIO.new(file_path, 'image/jpeg'),
            title: user_name,
            file_name: file_name + '.jpg',
            initial_comment: "#{user_name}が画像を投稿しました"
          )

        end
      end
    end
    head :ok
  end

  def slack_callback
    @body = JSON.parse(request.body.read)
    if request.headers["X-Slack-Retry-Num"] == nil
      case @body['type']
      when 'url_verification'
        render json: @body
        return
      when 'event_callback'
        case @body['event']['subtype']
        when 'message'
        when "file_share"
          @body['event']['subtype'] == "file_share"
          file = @body['event']['files'][0]
          #image_url = "https://#{ENV["NGROK_DOMAIN"]}.ngrok.io/uploads/#{file['id']}"
          #message = {
          #  type: "image",
          #  originalContentUrl: image_url,
          #  previewImageUrl: image_url
          #}
          #line_client.push_message(ENV["LINE_IMAGE_GROUP"], message)
          if file['title'] == 'ロマさん(LINE)'
            if @body['event']['channel'] == ENV['SLACK_MESSAGE_CHANNEL_ID']
              system("osascript message_group_click.scpt")
              fetch_and_save_image(file)
              p "--------------------"
              p "copied!"
              p "sleep 2"
              sleep 2
              p "メッセージグループに画像を貼り付けるよ！"
              p "--------------------"
              system("osascript line_paste.scpt")
            elsif @body['event']['channel'] == ENV['SLACK_IMAGE_CHANNEL_ID']
              system("osascript image_group_click.scpt")
              fetch_and_save_image(file)
              p "--------------------"
              p "copied!"
              p "sleep 2"
              sleep 2
              p "スクショグループに画像を貼り付けるよ！"
              p "--------------------"
              system("osascript line_paste.scpt")
            else
              raise "変なチャンネルに投稿してるよ"
            end
          else
            p "--------------------"
            p " 誰かの画像なので特に処理しません"
            p "--------------------"
          end
        when nil
          text = @body['event']['text']
          #message = {
          #  type: 'text',
          #  text: text
          #}
          #line_client.push_message(ENV["LINE_MESSAGE_GROUP"], message)
          if @body['event']['channel'] == ENV['SLACK_MESSAGE_CHANNEL_ID']
            system("osascript message_group_click.scpt")#下
            p "--------------------"
            p "sleep 1"
            sleep 1
            system("echo '#{text}' | pbcopy")
            p "copied!"
            p "sleep 0.5"
            sleep 0.5
            p "メッセージグループに文字を貼り付けるよ！"
            p "--------------------"
            system("osascript line_paste.scpt")
          elsif @body['event']['channel'] == ENV['SLACK_IMAGE_CHANNEL_ID']
            system("osascript image_group_click.scpt")#上
            p "--------------------"
            p "sleep 1"
            sleep 1
            system("echo '#{text}' | pbcopy")
            p "copied!"
            p "sleep 0.5"
            sleep 0.5
            p "スクショグループに文字を貼り付けるよ！"
            p "--------------------"
            system("osascript line_paste.scpt")
          else
            raise "変なチャンネルに投稿してるよ"
          end
        when "bot_message"
          puts "BOTメッセージな為、何も処理しませんでした"
        else
          puts "他のタイプです。"
        end
        head :ok
        return
      end
    else
      puts "特に何も処理しませんでした"
      head :ok
      return
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
