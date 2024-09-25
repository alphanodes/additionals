# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class WikiControllerTest < Additionals::ControllerTest
  fixtures :projects,
           :users,
           :roles,
           :members,
           :member_roles,
           :trackers,
           :groups_users,
           :projects_trackers,
           :enabled_modules,
           :issue_statuses,
           :issues,
           :enumerations,
           :custom_fields,
           :custom_values,
           :custom_fields_trackers,
           :wikis

  WIKI_MACRO_USER_ID = 2

  def setup
    prepare_tests
    EnabledModule.create project_id: 1, name: 'wiki'
  end

  def test_show_with_youtube_macro
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    page = WikiPage.generate! content: '{{youtube(KMU0tzLwhbE)}}',
                              title: __method__.to_s

    get :show,
        params: { project_id: 1, id: page.title }

    assert_response :success
    assert_select 'iframe[src=?]', '//www.youtube-nocookie.com/embed/KMU0tzLwhbE'
  end

  def test_show_with_meteoblue_macro
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    page = WikiPage.generate! content: '{{meteoblue(münchen_deutschland_2867714)}}',
                              title: __method__.to_s

    get :show,
        params: { project_id: 1, id: page.title }

    assert_response :success
    assert_select 'iframe', src: %r{^https://www\.meteoblue\.com/en/weather/widget/daily/(.*)}
  end

  def test_show_with_vimeo_macro
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    page = WikiPage.generate! content: '{{vimeo(142849533)}}',
                              title: __method__.to_s

    get :show,
        params: { project_id: 1, id: page.title }

    assert_response :success
    assert_select 'iframe[src=?]', '//player.vimeo.com/video/142849533'
  end

  def test_show_with_slideshare_macro
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    page = WikiPage.generate! content: '{{slideshare(57941706)}}',
                              title: __method__.to_s

    get :show,
        params: { project_id: 1, id: page.title }

    assert_response :success
    assert_select 'iframe[src=?]', '//www.slideshare.net/slideshow/embed_code/57941706'
  end

  def test_show_with_google_docs_macro
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    page = WikiPage.generate! content: '{{google_docs(https://docs.google.com/spreadsheets/d/e/RANDOMCODE/pubhtml)}}',
                              title: __method__.to_s

    get :show,
        params: { project_id: 1, id: page.title }

    assert_response :success
    assert_select 'iframe[src=?]', 'https://docs.google.com/spreadsheets/d/e/RANDOMCODE/pubhtml?widget=true&headers=false'
  end

  def test_show_with_iframe_macro
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    page = WikiPage.generate! content: '{{iframe(https://www.redmine.org/)}}',
                              title: __method__.to_s

    get :show,
        params: { project_id: 1, id: page.title }

    assert_response :success
    assert_select 'iframe[src=?]', 'https://www.redmine.org/'
  end

  def test_show_with_twitter_macro
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    page = WikiPage.generate! content: '{{twitter(alphanodes)}}',
                              title: __method__.to_s

    get :show,
        params: { project_id: 1, id: page.title }

    assert_response :success
    assert_select 'a.twitter'
    assert_select 'a[href=?]', 'https://twitter.com/alphanodes',
                  text: '@alphanodes'

    page.content.text = '{{twitter(@alphanodes)}}'

    assert_save page.content
    get :show,
        params: { project_id: 1, id: page.title }

    assert_select 'a.twitter'
    assert_select 'a[href=?]', 'https://twitter.com/alphanodes',
                  text: '@alphanodes'

    page.content.text = '{{twitter(#alphanodes)}}'

    assert_save page.content
    get :show,
        params: { project_id: 1, id: page.title }

    assert_select 'a.twitter'
    assert_select 'a[href=?]', 'https://twitter.com/hashtag/alphanodes',
                  text: '#alphanodes'
  end

  def test_show_with_reddit_macro
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    page = WikiPage.generate! content: '{{reddit(redmine)}}',
                              title: __method__.to_s

    get :show,
        params: { project_id: 1, id: page.title }

    assert_response :success
    assert_select 'a.reddit'
    assert_select 'a[href=?]', 'https://www.reddit.com/r/redmine',
                  text: 'r/redmine'

    page.content.text = '{{reddit(u/redmine)}}'

    assert_save page.content
    get :show,
        params: { project_id: 1, id: page.title }

    assert_select 'a.reddit'
    assert_select 'a[href=?]', 'https://www.reddit.com/username/redmine',
                  text: 'u/redmine'

    page.content.text = '{{reddit(r/redmine)}}'

    assert_save page.content
    get :show,
        params: { project_id: 1, id: page.title }

    assert_select 'a.reddit'
    assert_select 'a[href=?]', 'https://www.reddit.com/r/redmine',
                  text: 'r/redmine'
  end

  def test_show_last_updated_by_macro
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    page = WikiPage.generate! content: '{{last_updated_by}}',
                              title: __method__.to_s

    get :show,
        params: { project_id: 1, id: page.title }

    assert_response :success
    assert_select 'span.last-updated-by'
    assert_select 'a[href=?]', '/users/2',
                  text: 'jsmith'
  end

  def test_show_last_updated_at_macro
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    page = WikiPage.generate! content: '{{last_updated_at}}',
                              title: __method__.to_s

    get :show,
        params: { project_id: 1, id: page.title }

    assert_response :success
    assert_select 'span.last-updated-at'
    assert_select 'a[href=?]', '/projects/ecookbook/activity'
  end

  def test_show_recently_updated_macro
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    page = WikiPage.generate! content: '{{recently_updated}}',
                              title: __method__.to_s

    get :show,
        params: { project_id: 1, id: page.title }

    assert_response :success
    assert_select 'div.recently-updated'
  end

  def test_show_with_members_macro
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    page = WikiPage.generate! content: '{{members}}',
                              title: __method__.to_s

    get :show,
        params: { project_id: 1, id: page.title }

    assert_response :success
    assert_select 'div.wiki div.user'
  end

  def test_show_with_new_issue_macro
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    page = WikiPage.generate! content: '{{new_issue}}',
                              title: __method__.to_s

    get :show,
        params: { project_id: 1, id: page.title }

    assert_response :success
    assert_select 'div.wiki a.macro-new-issue'
  end

  def test_show_with_group_users_macro
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    page = WikiPage.generate! content: '{{group_users(A Team)}}',
                              title: __method__.to_s

    get :show,
        params: { project_id: 1, id: page.title }

    assert_response :success
    assert_select 'div.wiki div.user'
  end

  def test_show_with_projects_macro
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    page = WikiPage.generate! content: '{{projects}}',
                              title: __method__.to_s

    get :show,
        params: { project_id: 1, id: page.title }

    assert_response :success
    assert_select 'div.wiki div.additionals-projects tr.project'
  end

  def test_show_with_fa_macro
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    page = WikiPage.generate! content: '{{fa(adjust)}}',
                              title: __method__.to_s

    get :show,
        params: { project_id: 1, id: page.title }

    assert_response :success
    assert_select 'i.fas.fa-adjust'
  end

  def test_show_with_redmine_issue_macro
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    page = WikiPage.generate! content: '{{redmine_issue(12066)}}',
                              title: __method__.to_s

    get :show,
        params: { project_id: 1, id: page.title }

    assert_response :success
    assert_select 'a[href=?]', 'https://www.redmine.org/issues/12066'
  end

  def test_show_with_redmine_issue_with_absolute_url_macro
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    page = WikiPage.generate! content: '{{redmine_issue(http://www.redmine.org/issues/12066)}}',
                              title: __method__.to_s

    get :show,
        params: { project_id: 1, id: page.title }

    assert_response :success
    assert_select 'a[href=?]', 'https://www.redmine.org/issues/12066'
  end

  def test_show_with_redmine_wiki_macro
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    page = WikiPage.generate! content: '{{redmine_wiki(RedmineInstall)}}',
                              title: __method__.to_s

    get :show,
        params: { project_id: 1, id: page.title }

    assert_response :success
    assert_select 'a[href=?]', 'https://www.redmine.org/projects/redmine/wiki/RedmineInstall'
  end

  def test_show_with_redmine_wiki_with_absolute_url_macro
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    page = WikiPage.generate! content: '{{redmine_wiki(http://www.redmine.org/projects/redmine/wiki/RedmineInstall)}}',
                              title: __method__.to_s

    get :show,
        params: { project_id: 1, id: page.title }

    assert_response :success
    assert_select 'a[href=?]', 'https://www.redmine.org/projects/redmine/wiki/RedmineInstall'
  end

  def test_show_with_gist_macro
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    page = WikiPage.generate! content: '{{gist(plentz/6737338)}}',
                              title: __method__.to_s

    get :show,
        params: { project_id: 1, id: page.title }

    assert_response :success
    assert_select 'script[src=?]', 'https://gist.github.com/plentz/6737338.js'
  end

  def test_show_with_tradeview_macro
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    page = WikiPage.generate! content: '{{tradingview(symbol=NASDAQ:AMZN, locale=en)}}',
                              title: __method__.to_s

    get :show,
        params: { project_id: 1, id: page.title }

    assert_response :success
    assert_select 'script[src=?]', 'https://s3.tradingview.com/tv.js'
  end

  def test_show_with_cryptocompare_macro
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    page = WikiPage.generate! content: '{{cryptocompare(fsyms=BTC;ETH, type=header_v3)}}',
                              title: __method__.to_s

    get :show,
        params: { project_id: 1, id: page.title }

    assert_response :success
    assert_select 'div.wiki div.cryptocompare',
                  text: %r{https://widgets\.cryptocompare\.com/serve/v3/coin/header\?fsyms=BTC,ETH&tsyms=EUR}
  end

  def test_show_with_date_macro
    @request.session[:user_id] = WIKI_MACRO_USER_ID

    valid_types = %w[current_date current_date_with_time current_year
                     current_month current_day current_hour current_minute
                     current_weekday current_weeknumber]

    content = +''
    valid_types.each do |type|
      content << "{{date(#{type})}}"
    end

    page = WikiPage.generate! content:,
                              title: __method__.to_s

    get :show,
        params: { project_id: 1, id: page.title }

    assert_response :success
    assert_select 'div.wiki', html: /{{date/, count: 0
    assert_select 'div.wiki span.current-date', count: valid_types.count
    assert_select 'div.wiki span.current-date', User.current.today.cweek.to_s
    assert_select 'div.flash.error', html: /Error executing/, count: 0
  end

  def test_show_with_date_macro_and_invalid_type
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    page = WikiPage.generate! content: '{{date(invalid_type_name)}}',
                              title: __method__.to_s

    get :show,
        params: { project_id: 1, id: page.title }

    assert_response :success
    assert_select 'div.flash.error', html: /Error executing/
  end

  def test_show_with_date_macro_custom_date
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    page = WikiPage.generate! content: '{{date(2017-02-25)}}',
                              title: __method__.to_s

    get :show,
        params: { project_id: 1, id: page.title }

    assert_response :success
    assert_select 'div.flash.error', html: /Error executing/, count: 0
  end

  def test_show_with_date_macro_invalid_custom_date
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    page = WikiPage.generate! content: '{{date(2017-02-30)}}',
                              title: __method__.to_s

    get :show,
        params: { project_id: 1, id: page.title }

    assert_response :success
    assert_select 'div.flash.error', html: /Error executing/
  end

  def test_show_with_asciinema_macro
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    page = WikiPage.generate! content: '{{asciinema(113463)}}',
                              title: __method__.to_s

    get :show,
        params: { project_id: 1, id: page.title }

    assert_response :success
    assert_select 'script[src=?]', '//asciinema.org/a/113463.js'
  end

  def test_show_user_with_current_user
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    page = WikiPage.generate! content: '{{user(current_user)}}',
                              title: __method__.to_s

    get :show,
        params: { project_id: 1, id: page.title }

    assert_response :success
    assert_select '#content a.user.active[href=?]', '/users/2',
                  text: 'John Smith'
  end

  def test_show_user_with_current_user_as_text
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    page = WikiPage.generate! content: '{{user(current_user, text=true)}}',
                              title: __method__.to_s

    get :show,
        params: { project_id: 1, id: page.title }

    assert_response :success
    assert_select '#content span.user.active', text: 'John Smith'
  end

  def test_show_user_with_id
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    page = WikiPage.generate! content: '{{user(1)}}',
                              title: __method__.to_s

    get :show,
        params: { project_id: 1, id: page.title }

    assert_response :success
    assert_select '#content a[href=?]', '/users/1',
                  text: 'Redmine Admin'
  end

  def test_show_user_with_id_fullname
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    page = WikiPage.generate! content: '{{user(1, format=firstname_lastname)}}',
                              title: __method__.to_s

    get :show,
        params: { project_id: 1, id: page.title }

    assert_response :success
    assert_select '#content a.user', text: 'Redmine Admin'
    assert_select '#content a[href=?]', '/users/1',
                  text: 'Redmine Admin'
  end

  def test_show_user_with_name
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    page = WikiPage.generate! content: '{{user(jsmith)}}',
                              title: __method__.to_s

    get :show,
        params: { project_id: 1, id: page.title }

    assert_response :success
    assert_select '#content a[href=?]', '/users/2',
                  text: 'John Smith'
  end

  def test_show_user_with_name_fullname
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    page = WikiPage.generate! content: '{{user(jsmith, format=firstname_lastname, avatar=true)}}',
                              title: __method__.to_s

    get :show,
        params: { project_id: 1, id: page.title }

    assert_response :success
    assert_select '#content a.user', text: 'John Smith'
    assert_select '#content a[href=?]', '/users/2',
                  text: 'John Smith'
  end
end
