class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
    :recoverable, :rememberable, :validatable

  after_save :update_access_token

  has_many :ratings,
    class_name: 'UserRating'

  validates :email, presence: true, uniqueness: true

  attr_accessor :rememberme_flag

  def self.email_exists?(email)
    # We are assuming the all emails are store in the db as lowercase
    User.find_by email: email.downcase
  end

  def first_name
    if candidate
      candidate.first_name
    else
      recruiter.first_name
    end
  end

  def last_name
    if candidate
      candidate.full_name.split.last
    else
      recruiter.full_name.split.last
    end
  end

  def full_name
    if candidate
      candidate.full_name
    else
      recruiter.full_name
    end
  end

  private

  def update_access_token
    command = AuthenticateUser.call(email, password)
    self.access_token = command.result if command.success?
  end
end