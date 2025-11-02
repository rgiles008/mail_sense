defmodule MailSense.Mail.MailContext do
  import Ecto.Query

  alias MailSense.Repo
  alias MailSense.Mail.Email
  alias MailSense.Accounts.GmailAccount

  def ingest_message_sync(acct, _conn, message_id, _token) do
    Oban.insert!(
      MailSense.Workers.SummarizeCategorizeWorker.new(%{
        gmail_account_id: acct.id,
        user_email: acct.email,
        message_id: message_id
      })
    )
  end

  def upsert_email!(acct_id, parsed, category, summary, reason) do
    attrs =
      Map.merge(parsed, %{
        gmail_account_id: acct_id,
        category_id: category.id,
        ai_summary: summary,
        ai_category_reason: reason,
        archived_at: DateTime.utc_now()
      })

    %Email{}
    |> Email.changeset(attrs)
    |> Repo.insert!(
      on_conflict: {:replace_all_except, [:id, :inserted_at]},
      conflict_target: :gmail_message_id
    )
  end

  def list_emails_by_category(cat_id) do
    Repo.all(from e in Email, where: e.category_id == ^cat_id, order_by: [desc: e.inserted_at])
  end

  def list_emails_by_ids(user_id, email_ids) do
    Repo.all(
      from e in Email,
        join: g in GmailAccount,
        on: g.id == e.gmail_account_id,
        where: g.user_id == ^user_id and e.id in ^email_ids,
        preload: [gmail_account: g]
    )
  end
end
