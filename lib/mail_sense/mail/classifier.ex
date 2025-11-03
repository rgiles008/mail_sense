defmodule MailSense.Mail.Classifier do
  alias MailSense.Repo
  alias MailSense.Mail.Category
  alias MailSense.Mail.CategoryEmbedding

  @embed_model "text-embedding-3-small"

  def ensure_category_embedding!(%Category{id: id} = cat) do
    Repo.get_by(CategoryEmbedding, category_id: id) || create_category_embedding!(cat)
  end

  defp create_category_embedding!(%Category{} = cat) do
    text = Enum.join([cat.name, cat.description, cat.exemplar], "\n")
    {:ok, vec} = embed(text)

    %CategoryEmbedding{category_id: cat.id, embedding: :erlang.term_to_binary(vec)}
    |> Repo.insert!()
  end

  def choose_category(email_fields, categories) do
    with {:ok, evec} <- embed(email_text(email_fields)) do
      scored =
        categories
        |> Enum.map(fn cat ->
          cvec = cat_embedding(cat)
          base = cosine(evec, cvec)
          rules = score_rules(email_fields, cat.rules || %{})
          %{cat: cat, score: base + rules, base: base, rules: rules}
        end)
        |> Enum.sort_by(& &1.score, :desc)

      case scored do
        [%{cat: top, score: s1}, %{score: s2} | _] when s1 - s2 < 0.05 ->
          {:tie, top, Enum.map(scored, & &1.cat)}

        [%{cat: top} | _] ->
          {:ok, top}

        _ ->
          :none
      end
    end
  end

  defp email_text(e),
    do: "#{e.subject}\n#{e.from}\n#{e.snippet}\n#{String.slice(e.body_text || "", 0, 4000)}"

  defp cat_embedding(cat) do
    ce = ensure_category_embedding!(cat)
    :erlang.binary_to_term(ce.embedding)
  end

  defp embed(text) do
    body = %{model: @embed_model, input: text}
    headers = [{"authorization", "Bearer " <> System.fetch_env!("OPENAI_API_KEY")}]

    case Req.post("https://api.openai.com/v1/embeddings", json: body, headers: headers) do
      {:ok, %{status: 200, body: %{"data" => [%{"embedding" => v}]}}} -> {:ok, v}
      other -> {:error, other}
    end
  end

  defp cosine(a, b) do
    dot = Enum.zip(a, b) |> Enum.reduce(0.0, fn {x, y}, acc -> acc + x * y end)
    na = :math.sqrt(Enum.reduce(a, 0.0, fn x, acc -> acc + x * x end))
    nb = :math.sqrt(Enum.reduce(b, 0.0, fn x, acc -> acc + x * x end))
    if na == 0.0 or nb == 0.0, do: 0.0, else: dot / (na * nb)
  end

  # Rule scoring helpers
  defp score_rules(email, rules) do
    s = String.downcase(email.subject || "")
    f = String.downcase(email.from || "")
    hdrs = email.raw_headers || %{}
    has_unsub = Map.get(hdrs, "List-Unsubscribe") != nil

    score = 0.0
    score = score + includes_any?(s, rules["subject_includes"]) * 0.15
    score = score + domain_match?(f, rules["from_domains"]) * 0.25
    score = score + if(has_unsub && rules["has_unsubscribe"], do: 0.1, else: 0.0)
    score + (rules["boosts"] || 0.0) - (rules["penalty"] || 0.0)
  end

  defp includes_any?(text, list) when is_list(list),
    do: if(Enum.any?(list, &String.contains?(text, String.downcase(&1))), do: 1.0, else: 0.0)

  defp includes_any?(_, _), do: 0.0

  defp domain_match?(from, list) when is_list(list),
    do:
      if(Enum.any?(list, &String.contains?(from, "@" <> String.downcase(&1))), do: 1.0, else: 0.0)

  defp domain_match?(_, _), do: 0.0
end
