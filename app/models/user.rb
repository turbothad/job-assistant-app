class User < ApplicationRecord
  has_secure_password
  
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :first_name, presence: true
  validates :last_name, presence: true
  
  # Associations
  has_many :chat_messages, dependent: :destroy
  has_many :job_applications, dependent: :destroy
  
  def full_name
    "#{first_name} #{last_name}"
  end
end
