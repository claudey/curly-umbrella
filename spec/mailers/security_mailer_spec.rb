require "rails_helper"

RSpec.describe SecurityMailer, type: :mailer do
  describe "critical_alert" do
    let(:mail) { SecurityMailer.critical_alert }

    it "renders the headers" do
      expect(mail.subject).to eq("Critical alert")
      expect(mail.to).to eq(["to@example.org"])
      expect(mail.from).to eq(["from@example.com"])
    end

    it "renders the body" do
      expect(mail.body.encoded).to match("Hi")
    end
  end

  describe "security_alert" do
    let(:mail) { SecurityMailer.security_alert }

    it "renders the headers" do
      expect(mail.subject).to eq("Security alert")
      expect(mail.to).to eq(["to@example.org"])
      expect(mail.from).to eq(["from@example.com"])
    end

    it "renders the body" do
      expect(mail.body.encoded).to match("Hi")
    end
  end

  describe "user_security_alert" do
    let(:mail) { SecurityMailer.user_security_alert }

    it "renders the headers" do
      expect(mail.subject).to eq("User security alert")
      expect(mail.to).to eq(["to@example.org"])
      expect(mail.from).to eq(["from@example.com"])
    end

    it "renders the body" do
      expect(mail.body.encoded).to match("Hi")
    end
  end

end
