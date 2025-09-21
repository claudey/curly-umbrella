module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    def find_verified_user
      # Get user from session or token
      if verified_user = User.find_by(id: session_user_id)
        verified_user
      else
        reject_unauthorized_connection
      end
    end

    def session_user_id
      # Extract user ID from session or cookies
      # This depends on how Devise stores the user session
      session["warden.user.user.key"]&.dig(0, 0) ||
      cookies.encrypted["user_id"] ||
      request.session["user_id"]
    end
  end
end
