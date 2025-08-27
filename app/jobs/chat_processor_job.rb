class ChatProcessorJob < ApplicationJob
  queue_as :default

  def perform(user_message, room)
    # Process the user message with AI
    anthropic_service = AnthropicService.new
    
    # Check if user is asking about jobs
    if job_related?(user_message)
      ai_response = process_job_query(user_message, anthropic_service)
    else
      ai_response = process_general_query(user_message, anthropic_service)
    end
    
    # Broadcast AI response
    ActionCable.server.broadcast("chat_#{room}", {
      type: 'ai_message',
      message: ai_response,
      timestamp: Time.current.strftime('%H:%M')
    })
  end

  private

  def job_related?(message)
    job_keywords = %w[job jobs work career position role salary apply application company remote]
    job_keywords.any? { |keyword| message.downcase.include?(keyword) }
  end

  def process_job_query(message, anthropic_service)
    # For job-related queries, first search for relevant jobs
    keywords = extract_job_keywords(message)
    
    if keywords.any?
      scraper = JobsNowScraperService.new(keywords: keywords)
      jobs = scraper.call.first(3) # Get top 3 matching jobs
      
      if jobs.any?
        format_job_response(jobs, message, anthropic_service)
      else
        anthropic_service.chat_completion("The user asked: '#{message}'. No jobs were found matching their criteria. Please provide a helpful response about job searching strategies.")
      end
    else
      anthropic_service.chat_completion("The user asked about jobs: '#{message}'. Please provide helpful guidance about job searching and career advice.")
    end
  end

  def process_general_query(message, anthropic_service)
    anthropic_service.chat_completion("You are a helpful AI job assistant. The user said: '#{message}'. Please provide a helpful response.")
  end

  def extract_job_keywords(message)
    # Simple keyword extraction - could be enhanced with NLP
    tech_keywords = %w[ruby rails python javascript react nodejs java sql docker kubernetes aws]
    found_keywords = tech_keywords.select { |keyword| message.downcase.include?(keyword) }
    
    # If no tech keywords found, use general terms
    found_keywords.empty? ? ['software', 'engineer'] : found_keywords
  end

  def format_job_response(jobs, original_message, anthropic_service)
    job_summaries = jobs.map.with_index(1) do |job, index|
      "#{index}. #{job[:title]} at #{job[:company]} (#{job[:location]}) - #{job[:salary_range]}"
    end.join("\n")
    
    prompt = "The user asked: '#{original_message}'. I found these relevant jobs:\n\n#{job_summaries}\n\nPlease provide a helpful response that highlights these opportunities and gives advice on how to apply."
    
    ai_response = anthropic_service.chat_completion(prompt)
    
    # Append job URLs for easy access
    job_links = jobs.map.with_index(1) do |job, index|
      "🔗 Apply to Job #{index}: #{job[:job_url]}"
    end.join("\n")
    
    "#{ai_response}\n\n#{job_links}"
  end
end
