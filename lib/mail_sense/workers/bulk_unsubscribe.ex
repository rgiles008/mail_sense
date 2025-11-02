defmodule MailSense.Workers.BulkUnsubscribe do
  use Oban.Worker,
    queue: :ops,
    max_attempts: 3

  alias MailSense.Repo
  alias MailSense.Mail.Email
  alias MailSense.Mail.Unsubscribe

  def perform(%Oban.Job{args: %{"email_id" => email_id, "user_email" => user_email}}) do
    email = Repo.get!(Email, email_id)
    headers = email.raw_headers || %{}
    links = Email.extract_unsubscribe_links(headers, email.body_text)

    case Unsubscribe.do_unsubscribe(email.gmail_account, user_email, links, headers) do
      {:ok, _} ->
        Email.mark_unsubscribed!(email)
        :ok

      {:error, {_http_reason, reason}} ->
        Email.mark_unsubscribe_failed!(email, reason)
        {:error, reason}

      {:error, :no_unsubscribe} ->
        :ok
    end
  end
end
