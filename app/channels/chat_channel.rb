class ChatChannel < ApplicationCable::Channel
  def subscribed
    stream_from "chat_#{params[:room]}"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end

  def speak(data)
    # Handle user messages
    user_message = data['message']
    room = params[:room]
    
    # Broadcast user message immediately
    ActionCable.server.broadcast("chat_#{room}", {
      type: 'user_message',
      message: user_message,
      timestamp: Time.current.strftime('%H:%M')
    })
    
    # Process with AI asynchronously
    ChatProcessorJob.perform_later(user_message, room)
  end
end
