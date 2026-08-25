require "test_helper"

class MissionControlJobsTest < ActionDispatch::IntegrationTest
  test "GET /jobs is accessible when basic auth is disabled" do
    get "/jobs"
    assert_response :success
  end

  test "GET /jobs challenges with basic auth when enabled and configured" do
    with_basic_auth(user: "admin", password: "secret") do
      get "/jobs"
      assert_response :unauthorized

      get "/jobs", headers: basic_auth_header("admin", "secret")
      assert_response :success
    end
  end

  private

  # Active temporairement la Basic Auth avec des identifiants connus,
  # quelles que soient les valeurs des fichiers d'environnement.
  # Restaure l'état initial pour ne pas fuiter vers d'autres tests.
  def with_basic_auth(user:, password:)
    original_enabled = MissionControl::Jobs.http_basic_auth_enabled
    original_user = MissionControl::Jobs.http_basic_auth_user
    original_password = MissionControl::Jobs.http_basic_auth_password

    MissionControl::Jobs.http_basic_auth_enabled = true
    MissionControl::Jobs.http_basic_auth_user = user
    MissionControl::Jobs.http_basic_auth_password = password

    yield
  ensure
    MissionControl::Jobs.http_basic_auth_enabled = original_enabled
    MissionControl::Jobs.http_basic_auth_user = original_user
    MissionControl::Jobs.http_basic_auth_password = original_password
  end

  def basic_auth_header(user, password)
    {
      "Authorization" => ActionController::HttpAuthentication::Basic
        .encode_credentials(user, password)
    }
  end
end
