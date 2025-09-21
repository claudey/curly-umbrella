class TestController < ApplicationController
  skip_before_action :authenticate_user!

  def drawer
    render "test_drawer", layout: false
  end
end
