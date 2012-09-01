class User < ActiveRecord::Base
  authenticates_with_sorcery!
  attr_accessible :name, :email, :subscribe, :authentications_attributes

  scope :email_sendables, where(subscribe: true, activation_state: 'active')
  scope :newly, order('created_at DESC')

  has_many :authentications, dependent: :destroy
  accepts_nested_attributes_for :authentications

  before_save do
    if self.email_changed?
      self.activation_state = nil
    end
    unless self.active?
      self.activation_token ||= OpenSSL::Random.random_bytes(16).unpack("H*").first
    end
  end

  def access_token
    @access_token ||= authentications.find_by_provider(:github).try(:token)
  end

  def email_sendable?
    email.present? && subscribe
  end

  def active?
    'active' == activation_state
  end

  def watch_events_by_followings
    following_names = followings.map do |following|
      following['login']
    end
    WatchEvent.all_by(following_names)
  end

  def watch_events_by_followings_with_me
    watch_events_by_followings.by(username)
  end

  def followings
    return @followings if @followings
    max_page = 10
    @followings = []
    (1..max_page).each do |page|
      followings_in_one_page = github_client.following(username, page: page)
      break if followings_in_one_page.empty?
      @followings += followings_in_one_page
    end
    @followings
  end

  private

  def github_client
    @github_client ||= Octokit::Client.new(login: username, oauth_token: access_token)
  end
end
