defmodule MailSense.Factory do
  use ExMachina.Ecto, repo: MailSense.Repo

  def user_factory do
    %MailSense.Accounts.User{email: sequence(:email, &"user#{&1}@example.com")}
  end

  def gmail_account_factory do
    %MailSense.Mail.GmailAccount{
      user_id: build(:user).id,
      email: sequence(:g, &"u#{&1}@example.com"),
      access_token: "test_token",
      refresh_token: "refresh",
      expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
    }
  end

  def category_factory do
    %MailSense.Mail.Category{
      user_id: build(:user).id,
      name: sequence(:cat, &"Category #{&1}"),
      description: "Invoices & billing",
      rules: %{"subject_includes" => ["invoice"], "has_unsubscribe" => true}
    }
  end

  def email_factory do
    %MailSense.Mail.Email{
      gmail_message_id: sequence(:mid, &"m-#{&1}"),
      subject: "Your monthly invoice",
      from: "billing@acme.com",
      body_text: "Please see attached...",
      category_id: build(:category).id,
      summary: "Invoice summary",
      unsubscribe_http: nil,
      unsubscribe_mailto: nil,
      status: :imported
    }
  end
end
