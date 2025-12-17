require "test_helper"

class SessionTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "belongs to user" do
    session = Session.create!(user: @user, ip_address: "127.0.0.1", user_agent: "TestAgent")
    assert_equal @user, session.user
  end

  test "requires user" do
    session = Session.new(ip_address: "127.0.0.1", user_agent: "TestAgent")
    assert_not session.valid?
    assert_includes session.errors[:user], "must exist"
  end

  test "can store ip address" do
    session = Session.create!(user: @user, ip_address: "192.168.1.1", user_agent: "TestAgent")
    assert_equal "192.168.1.1", session.ip_address
  end

  test "can store user agent" do
    session = Session.create!(user: @user, ip_address: "127.0.0.1", user_agent: "Mozilla/5.0")
    assert_equal "Mozilla/5.0", session.user_agent
  end
end
