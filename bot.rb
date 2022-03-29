require 'telegram/bot'

require 'dotenv'
Dotenv.load

require 'net/http'
require 'uri'

require 'json'

$json_url = "#{ENV["JSON_URL"]}"
$json_api = "#{ENV["JSON_API"]}"
$logVar=1

def getJson
  uri = URI($json_url)

  Net::HTTP.start(uri.host, uri.port,use_ssl: true ) do |http|
    req = Net::HTTP::Get.new uri
    req['X-Master-Key'] = $json_api

    $response = http.request req # Net::HTTPResponse object
  end

  file= $response.body
  $data_hash = JSON.parse(file)['record']
end
getJson


def sendJson(tosendJson)
  uri = URI($json_url)

  Net::HTTP.start(uri.host, uri.port,use_ssl: true ) do |http|
    req = Net::HTTP::Put.new(uri)
    req['Content-Type'] = 'application/json'
    req['X-Master-Key'] = $json_api
    req.body = tosendJson

    $response = http.request req # Net::HTTPResponse object
    puts "JSON sent"
  end
end

require 'digest/md5'



token=ENV["API_TOKEN"]
$bot_username = ENV["BOT_USERNAME"]

def repyText_gen (typeVar)
  if typeVar=="done"
    $reply_text = "متن نهایی ساخته شد.
      
      برای اشتراک این متن می‌توانید از این لینک استفاده نمایید:
      https://t.me/#{$bot_username}?start=#{Digest::MD5.hexdigest("#{$waitingLockId}")[0...8]}

      تعداد متن‌ها: #{$messages_count}
      تعداد حروف: #{$newText.length}
      ---

      پیام نهایی:

      #{$newText}
      
      "
  elsif  typeVar=="single_text"
    $reply_text = "این متن اضافه شد و متن نهایی ساخته شد. 
      تعداد حروف: #{$newText.length}
      ---
     
      برای اشتراک این متن می‌توانید از این لینک استفاده نمایید:
      https://t.me/#{$bot_username}?start=#{Digest::MD5.hexdigest("#{$waitingLockId}")[0...8]}

      پیام نهایی:

      #{$newText}

      [Code: #{$waitingLockId}]
      "
  elsif typeVar=="start"
    $reply_text = "سلام! خوش‌اومدی #{$msg.from.first_name}. 🤖. روی لینکی که داخل پیامت هست کلیک کن وگرنه پیامت رو فوروارد کن." 
  elsif typeVar=="show_long_msg"
    if $long_message_to_show!=" "
      $reply_text = "پیام کامل که دنبالش بودی:
      ----
      #{$long_message_to_show}"
    else
      $reply_text = "نتونستم پیامی که دنبالشی رو پیدا کنم :("
    end
  elsif typeVar=="no_response"
    $reply_text = " #{$msg.text.delete_prefix("/start ")} 
    متاسفانه این پیام رو پیدا نکردم :(" 
  elsif typeVar=="merge"
    $reply_text = "الان برات متنت رو کوتاه می‌کنم. فقط برام دونه دونه پیام‌هاتو بفرست تا همه رو برات ترکیب کنم.!"
  elsif typeVar=="text2link"
    $reply_text = "متن خود را ارسال کنید"
  end
end

def resetVars
  $isWaiting=0
  $newText=""
  $singleTxt=0
  $waitingLockId=0
  $isText=0
  $message_orig={}
  $showMsg=0
  $msg=0
end
resetVars

def newMsg (hashVar,isExport)
  $data_hash["#{hashVar}"] = {
    "code": hashVar,
    "is_secure": 0, 
    "timer": 0, 
    "txt2png": 0,
    "chat_id": $msg.chat.id,
    "message_id": $waitingLockId,
    "shorten_text": $newText.slice(0..5),
    "full_text":$newText
  }
  if isExport=="export"
    sendJson JSON.dump($data_hash)
  end
end

def checkLogStatus
  if $msg.text == "off1"
    $logVar=0
  elsif $msg.text == "on1"
    $logVar=1
  end
end

def waitingResponse
  if $msg.text != "/merge" && $msg.text != "/text2link" 
    $messages_count=$messages_count+1
    $newText = "#{$newText} 
    #{$msg.text}"
    $reply_text = "این متن اضافه شد. 
    تعداد متن‌ها: #{$messages_count}
    تعداد حروف: #{$newText.length}
    ---
    در صورتی که متن دیگری برای ارسال ندارید، بر روی /done کلیک کنید.

    [Code: #{$waitingLockId}]
    "
    codeVar_generated = "#{Digest::MD5.hexdigest("#{$waitingLockId}")[0...8]}"
    newMsg codeVar_generated,"hold"
  else
    $reply_text = "در حال ارسال متن هستید. ‍
    تعداد متن‌ها: #{$messages_count}
    تعداد حروف: #{$newText.length}
    ---
    در صورتی که متن دیگری برای ارسال ندارید، بر روی /done کلیک کنید.
    "
  end
end



Telegram::Bot::Client.run(token) do |bot|
  puts "telegram bot started"
  bot.listen do |message|
    $msg=message
    checkLogStatus

    if message.text
      $isText=1
      codeVar = message.text
      if codeVar.length>6 && message.text.include?("/start")
        codeVar= codeVar.delete_prefix("/start ")
        $message_orig = $data_hash["#{codeVar}"]
        $showMsg=1
      end
    end

    if $isWaiting==1 && message.text != "/start" && message.text != "/done" && $singleTxt==0
      waitingResponse
    elsif  message.text == "/done"
      repyText_gen "done"
      sendJson JSON.dump($data_hash)
      resetVars 
    elsif $singleTxt==1
      $messages_count=1
      $newText = "#{message.text}"
      repyText_gen "single_text"
      codeVar_generated = "#{Digest::MD5.hexdigest("#{$waitingLockId}")[0...8]}"      
      newMsg codeVar_generated,"export"
      resetVars 
    elsif $isText==1 && message.text!="/merge" && message.text!="/text2link"
      if message.text=="/start"
        repyText_gen "start"
      elsif $showMsg==1 && message.text.include?("/start")
        $long_message_to_show=" "
        if "#{$message_orig}" != ""
          $long_message_to_show = $message_orig.values[7]
        end
        repyText_gen "show_long_msg"
      else
        repyText_gen "no_response"
      end
    elsif message.text=="/merge"
      repyText_gen "merge"
      $isWaiting = 1
      $waitingLockId="#{message.chat.id}#{message.message_id}"
      $messages_count=0
    elsif message.text=="/text2link"
      repyText_gen "text2link"
      $singleTxt=1
      $isWaiting = 1
      $waitingLockId="#{message.chat.id}#{message.message_id}"
      $messages_count=0
    elsif $isText==1
      if message.text.length <15
        $reply_text = "پیداش نمی‌کنم که #{message.text} یعنی چی :("
      else
        $reply_text = "پیداش نمی‌کنم  :("
      end
    end

    if message.text
      bot.api.send_message(chat_id: message.chat.id, reply_to_message_id: message.message_id, text: $reply_text)
    end

    if $logVar==1
      bot.api.send_message(chat_id: ENV['ADMIN_ID'] , text: "
        🎺
        🕸 New prey: 
        ⌗ Started from: #{message.text.delete_prefix("/start ")}


        🃏 User Captured 

            ⮑ 🎯 Chat ID: #{message.chat.id}

            ⮑ ☠ Username: 🎯 @#{message.from.username}

            ⮑ 🎱 name:  #{message.from.first_name}

            - message_orig: #{$message_orig}
            - codeVar: #{codeVar}
            - isWaiting: #{$isWaiting}
            - messages_count: #{$messages_count}
          " )
    end
  end
end
