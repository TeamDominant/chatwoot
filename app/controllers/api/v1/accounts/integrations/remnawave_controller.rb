class Api::V1::Accounts::Integrations::RemnawaveController < Api::V1::Accounts::BaseController
  before_action :fetch_hook
  before_action :fetch_contact, only: [:user, :user_action]

  def user
    telegram_id = @contact.additional_attributes&.dig('social_telegram_user_id')
    return render json: { error: 'no_telegram_id' }, status: :unprocessable_entity if telegram_id.blank?

    data = remnawave_get("/api/users/by-telegram-id/#{telegram_id}")
    render json: { user: data['response'] }
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def user_action
    telegram_id = @contact.additional_attributes&.dig('social_telegram_user_id')
    return render json: { error: 'no_telegram_id' }, status: :unprocessable_entity if telegram_id.blank?

    user_data = remnawave_get("/api/users/by-telegram-id/#{telegram_id}")
    uuid = user_data.dig('response', 'uuid')
    return render json: { error: 'user_not_found' }, status: :not_found if uuid.blank?

    action_path = case params[:action_type]
                  when 'reset_traffic' then "/api/users/#{uuid}/actions/reset-traffic"
                  when 'enable'        then "/api/users/#{uuid}/actions/enable"
                  when 'disable'       then "/api/users/#{uuid}/actions/disable"
                  else return render json: { error: 'invalid_action' }, status: :unprocessable_entity
                  end

    remnawave_post(action_path)
    render json: { success: true }
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    @hook.destroy!
    head :ok
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def fetch_hook
    @hook = Integrations::Hook.find_by!(account: Current.account, app_id: 'remnawave')
  end

  def fetch_contact
    @contact = Current.account.contacts.find_by(id: params[:contact_id])
    render json: { error: 'contact_not_found' }, status: :not_found unless @contact
  end

  def api_base_url
    @hook.settings['api_url'].to_s.chomp('/')
  end

  def api_headers
    { 'Authorization' => "Bearer #{@hook.settings['api_token']}", 'Content-Type' => 'application/json' }
  end

  def remnawave_get(path)
    response = HTTParty.get("#{api_base_url}#{path}", headers: api_headers, timeout: 10)
    raise "Remnawave API error #{response.code}" unless response.success?

    response.parsed_response
  end

  def remnawave_post(path, body = nil)
    response = HTTParty.post("#{api_base_url}#{path}", headers: api_headers, body: body&.to_json, timeout: 10)
    raise "Remnawave API error #{response.code}" unless response.success?

    response.parsed_response
  end
end
