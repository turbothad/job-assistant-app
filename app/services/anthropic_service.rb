class AnthropicService
  def initialize
    @client = Anthropic::Client.new(access_token: ENV['ANTHROPIC_API_KEY'])
  end

  def chat_completion(messages, system_prompt = nil)
    parameters = {
      model: 'claude-3-5-sonnet-20241022',
      max_tokens: 4000,
      messages: format_messages(messages)
    }
    
    parameters[:system] = system_prompt if system_prompt

    response = @client.messages(parameters: parameters)
    handle_response(response)
  end

  def analyze_job_preferences(user_input)
    system_prompt = <<~PROMPT
      You are an AI assistant helping users find jobs on Jobs.Now. Your role is to:
      1. Extract job preferences from user input
      2. Ask clarifying questions to understand their needs
      3. Guide them through the job search process
      
      Extract and return structured information about:
      - Job categories (Engineering, Data Science, Finance, etc.)
      - Location preferences
      - Salary expectations
      - Experience level
      - Remote/hybrid/onsite preferences
      
      If information is missing, ask specific follow-up questions.
      Be conversational and helpful.
    PROMPT

    messages = [{ role: 'user', content: user_input }]
    chat_completion(messages, system_prompt)
  end

  def match_jobs_to_preferences(jobs, preferences)
    system_prompt = <<~PROMPT
      You are an AI job matching assistant. Given a list of job postings and user preferences,
      rank and filter the jobs based on how well they match the user's criteria.
      
      For each job, provide:
      1. Match score (1-10)
      2. Reasoning for the match
      3. Any concerns or notes
      
      Return as JSON with job_id, match_score, and reasoning for each job.
    PROMPT

    user_content = {
      jobs: jobs.map(&:attributes),
      preferences: preferences
    }.to_json

    messages = [{ role: 'user', content: user_content }]
    chat_completion(messages, system_prompt)
  end

  private

  def format_messages(messages)
    messages.map do |msg|
      {
        role: msg[:role],
        content: msg[:content]
      }
    end
  end

  def handle_response(response)
    if response
      response
    else
      Rails.logger.error "Anthropic API Error: No response received"
      { error: "API request failed" }
    end
  rescue => e
    Rails.logger.error "Anthropic API Error: #{e.message}"
    { error: "API request failed", message: e.message }
  end
end
