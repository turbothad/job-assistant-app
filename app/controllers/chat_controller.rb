class ChatController < ApplicationController
  def index
    @room = params[:room] || 'general'
  end

  def create
    # This will be handled by Action Cable, so just redirect to index
    redirect_to chat_index_path
  end
end
