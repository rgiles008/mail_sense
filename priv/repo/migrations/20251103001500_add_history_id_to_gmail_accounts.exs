defmodule MailSense.Repo.Migrations.AddHistoryIdToGmailAccounts do
  use Ecto.Migration

  def change do
    alter table(:gmail_accounts) do
      add :history_id, :string
      add :last_polled_at, :utc_datetime
    end

    create index(:gmail_accounts, [:history_id])
  end
end
