
require 'feature_helper'

describe 'OAuth' do
  let(:user) { FactoryGirl.create(:user, email: 'testy.mctesterson@gsa.gov') }
  let(:client_app) { FactoryGirl.create(:application, name: 'Test App') }
  let(:requested_scopes) { 'profile.email profile.last_name' }

  # Set up an OAuth2::Client instance for HTTP calls that happen outside of the
  # Capybara context. More detail here:
  # https://github.com/doorkeeper-gem/doorkeeper/wiki/Testing-your-provider-with-OAuth2-gem
  let(:oauth_client) do
    OAuth2::Client.new(
      client_app.uid, client_app.secret, site: 'http://www.example.com'
    ) do |b|
      b.request :url_encoded
      b.adapter :rack, Capybara.app
    end
  end

  def visit_oauth_authorize_url(client, app, scopes)
    visit(client.auth_code.authorize_url(
      redirect_uri: app.redirect_uri,
      scope: scopes,
      state: 'state'
    ))
  end

  shared_examples 'authorizable' do
    scenario 'user can authorize' do
      expect(@auth_page).to be_displayed
      @auth_page.allow_button.click

      token = @token_page.get_token(oauth_client, client_app.redirect_uri)
      expect(token).to_not be_expired
    end
  end

  shared_examples 'scope error' do
    scenario 'displays scope error message' do
      expect(@auth_page).to be_displayed
      expect(@auth_page).to have_oauth_error_message
      expect(@auth_page.oauth_error_message.text).to(
        include('The requested scope is invalid, unknown, or malformed.'))
    end
  end

  shared_examples 'uses existing authorization' do
    it 'skips authorization' do
      token = @token_page.get_token(oauth_client, client_app.redirect_uri)
      expect(token).to_not be_expired
    end
  end

  before :each, authorized: true do
    FactoryGirl.create(:access_token,
                       application: client_app,
                       resource_owner_id: user.id)
  end

  before :each, logged_in: true do
    login user
  end

  before :each do
    visit_oauth_authorize_url(oauth_client, client_app, requested_scopes)
  end

  describe 'Authorization' do
    before :each do
      @auth_page = OAuth2::AuthorizationPage.new
      @token_page = OAuth2::TokenPage.new
    end

    context 'when not logged in' do
      let(:provider) { :google_oauth2 }

      before :each do
        @sign_in_page = SignInPage.new
        expect(@sign_in_page).to be_displayed

        OmniAuth.config.test_mode = true
        OmniAuth.config.mock_auth[provider] = OmniAuth::AuthHash.new(
          provider: provider,
          uid: user.uid,
          info: OmniAuth::AuthHash.new(
            email: user.email
          )
        )
      end

      scenario 'redirects to login page and preserves session' do
        @sign_in_page.google_button.click
        expect(@auth_page).to be_displayed
      end

      scenario 'it tells you why you\'re here' do
        @sign_in_page = SignInPage.new
        expect(@sign_in_page).to have_welcome
        expect(@sign_in_page.welcome).to(
          have_content('Welcome to MyUSA from Test App'))
      end

      scenario 'does not show flash redirect message' do
        expect(@sign_in_page).to_not have_content(
          'You need to sign in or sign up before continuing'
        )
      end
    end

    context 'when logged in', logged_in: true do
      context 'with valid url params' do
        let(:user2) { FactoryGirl.create(:user) }

        scenario 'user can switch to another user' do
          @sign_in_page = SignInPage.new

          expect(@auth_page).to be_displayed

          # FIXME
          pending("The page is currently missing a \"Not Me\" link")
          pass
          @auth_page.not_me_link.click

          expect(@sign_in_page).to be_displayed
          @sign_in_page.email.set user2.email
          @sign_in_page.submit.click

          open_email(user2.email)
          current_email.click_link('click here')

          expect(@auth_page).to be_displayed
        end

        scenario 'user can authorize' do
          # Authorize the client app
          expect(@auth_page).to be_displayed
          @auth_page.allow_button.click

          token = @token_page.get_token(oauth_client, client_app.redirect_uri)
          expect(token).to_not be_expired
        end

        scenario 'user can deny by clicking "No Thanks"' do
          expect(@auth_page).to be_displayed
          @auth_page.cancel_button.click
          expect(JSON.parse(@auth_page.body)['error']).to(
            eq('access_denied'))
        end

        scenario 'user can deny by clicking "head back to" link' do
          expect(@auth_page).to be_displayed

          # FIXME
          pending("The current form is missing a head back link")
          pass

          @auth_page.head_back_link.click
          expect(JSON.parse(@auth_page.body)['error']).to eq('access_denied')
        end

        context 'app has TOS links' do
          let(:client_app) { FactoryGirl.create(:application, name: 'Test App', tos_link: 'http://example.com/tos', privacy_policy_link: 'http://example.com/privacy') }
          scenario 'page displays links to TOS' do
            # FIXME
            pending("The TOS link has not been added yet")
            pass

            expect(@auth_page).to be_displayed
            expect(@auth_page).to have_tos_link
            expect(@auth_page).to have_privacy_policy_link
          end
        end

        scenario 'user can select scopes' do
          # FIXME
          pending("The form is missing some elements")
          pass

          expect(@auth_page).to be_displayed
          @auth_page.scope_list.uncheck('Email')
          @auth_page.allow_button.click

          token = @token_page.get_token(oauth_client, client_app.redirect_uri)
          expect(token['scope']).to eq('profile.last_name')
        end

        scenario 'user can update profile' do
          # FIXME
          pending("The form is missing some elements")
          pass
          expect(@auth_page).to have_no_profile_email
          @auth_page.profile_last_name.set 'McTesterson'
          @auth_page.allow_button.click

          token = @token_page.get_token(oauth_client, client_app.redirect_uri)

          profile = JSON.parse token.get('/api/profile').body
          expect(profile['last_name']).to eq('McTesterson')
          expect(profile['email']).to eq('testy.mctesterson@gsa.gov')
        end

        context 'profile data is invalid' do
          let(:client_app) do
            FactoryGirl.create(:application, scopes: 'profile.phone_number')
          end
          let(:requested_scopes) { 'profile.phone_number' }
          scenario 'user cannot save or authorize' do
            # FIXME
            pending("The form is missing a div.alert.alert-danger div")
            pass

            expect(@auth_page).to be_displayed
            @auth_page.profile_phone_number.set 'foobar'
            @auth_page.allow_button.click

            expect(@auth_page).to be_displayed
            expect(@auth_page.flash_error_message).to(
              have_content('Phone number'))
          end
        end

        context 'when no scopes are requested' do
          let(:requested_scopes) { nil }
          it_behaves_like 'uses existing authorization'
        end
      end

      context 'when user is already authorized', authorized: true do
        context 'with the same set of scopes requested' do
          let(:authorized_scopes) { requested_scopes }
          it_behaves_like 'uses existing authorization'
        end

        context 'with additional scopes authorized' do
          let(:authorized_scopes) { "#{requested_scopes} profile.address" }
          it_behaves_like 'uses existing authorization'
        end

        context 'when no scopes are requested' do
          let(:authorized_scopes) { 'profile.email' }
          let(:requested_scopes) { '' }
          it_behaves_like 'uses existing authorization'
        end

        context 'when requested scopes are not part of authorization' do
          let(:authorized_scopes) { 'profile.email' }
          it 'prompts user for new authorization' do
            expect(@auth_page).to be_displayed
          end
        end
      end

      context 'with lots of scopes' do
        let(:scopes) do
          'profile.email profile.title profile.first_name ' \
          'profile.middle_name profile.last_name profile.phone_number ' \
          'profile.suffix profile.address profile.address2 profile.zip ' \
          'profile.gender profile.marital_status profile.is_parent ' \
          'profile.is_student profile.is_veteran profile.is_retired ' \
          'notifications'
        end
        let(:client_app) { FactoryGirl.create(:application, scopes: scopes) }
        let(:requested_scopes) { scopes }

        # FIXME
        xit 'displays the proper scopes' do
          expect(@auth_page.scopes.map(&:text)).to eq(
            ['Email Address', 'Title', 'First Name', 'Middle Name', 'Last Name',
             'Suffix', 'Home Address', 'Home Address (Line 2)', 'Zip Code',
             'Phone Number', 'Gender', 'Marital Status', 'Are you a Parent?',
             'Are you a Student?', 'Are you a Veteran?', 'Are you Retired?',
             'Allow the application send you notifications via MyUSA'])
        end

        pending do
          it_behaves_like 'authorizable'
        end
      end

      context 'with non-public (sandboxed) app' do
        let(:owner) { FactoryGirl.create(:user, email: 'owner@gsa.gov') }
        let(:client_app) do
          FactoryGirl.create(:application, public: false, owner: owner)
        end

        context 'current user is client application owner' do
          let(:owner) { user }

          it_behaves_like 'authorizable'
        end

        # context 'current user is a client application developer' do
        #   pending 'implement developers'
        #   let(:client_app) do
        #     FactoryGirl.create(:application, public: false,
        #                                      owners: [owner],
        #                                      developers: [user])
        #   end
        #
        #   it_behaves_like 'authorizable'
        # end

        context 'current user is not client application owner' do
          scenario 'displays unknown application error' do
            expect(@auth_page).to be_displayed
            expect(@auth_page).to have_error_message
            expect(@auth_page.error_message.text).to(
              include('Client authentication failed due to unknown client, ' \
                      'no client authentication included, or unsupported ' \
                      'authentication method.'))
          end
        end
      end

      context 'with bad scope value' do
        let(:requested_scopes) { 'foo bar baz' }

        it_behaves_like 'scope error'
      end

      context 'with scope not in client application scopes' do
        let(:requested_scopes) { 'profile.city' }

        it_behaves_like 'scope error'
      end
    end
  end

  # TODO move these specs to home page spec upon creation
  describe 'header and footer content' do
    let(:requested_scopes) { 'profile.email profile.last_name' }

    before :each do
      @auth_page = OAuth2::AuthorizationPage.new
      @token_page = OAuth2::TokenPage.new
    end

    context 'user is logged in' do
      before :each do
        login user
        visit_oauth_authorize_url(oauth_client, client_app, requested_scopes)
      end

      describe 'header and footer content' do
        xit 'has settings menu' do
          expect(@auth_page).to have_settings
        end

        it 'does not have sign in button' do
          expect(@auth_page).to_not have_sign_in_button
        end

        it 'has footer content' do
          expect(@auth_page).to have_footer
        end

        it 'has ownership statement' do
          expect(@auth_page).to have_ownership
        end
      end
    end
  end

end
