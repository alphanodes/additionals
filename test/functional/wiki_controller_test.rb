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
           :wikis,
           :wiki_pages,
           :wiki_contents

  WIKI_MACRO_USER_ID = 2

  def setup
    prepare_tests
    EnabledModule.create project_id: 1, name: 'wiki'
    @project = projects :projects_001
    @wiki = @project.wiki
    @page_name = 'additionals_macro_test'
    @page = @wiki.find_or_new_page @page_name
    @page.content = WikiContent.new
    @page.content.text = 'test'
    @page.save!
  end

  def test_show_with_youtube_macro
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    @page.content.text = '{{youtube(KMU0tzLwhbE)}}'
    @page.content.save!
    get :show,
        params: { project_id: 1, id: @page_name }
    assert_response :success
    assert_select 'iframe[src=?]', '//www.youtube-nocookie.com/embed/KMU0tzLwhbE'
  end

  def test_show_with_meteoblue_macro
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    @page.content.text = '{{meteoblue(münchen_deutschland_2867714)}}'
    @page.content.save!
    get :show,
        params: { project_id: 1, id: @page_name }
    assert_response :success
    assert_select 'iframe', src: %r{^https://www\.meteoblue\.com/en/weather/widget/daily/(.*)}
  end

  def test_show_with_vimeo_macro
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    @page.content.text = '{{vimeo(142849533)}}'
    @page.content.save!
    get :show,
        params: { project_id: 1, id: @page_name }
    assert_response :success
    assert_select 'iframe[src=?]', '//player.vimeo.com/video/142849533'
  end

  def test_show_with_slideshare_macro
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    @page.content.text = '{{slideshare(57941706)}}'
    @page.content.save!
    get :show,
        params: { project_id: 1, id: @page_name }
    assert_response :success
    assert_select 'iframe[src=?]', '//www.slideshare.net/slideshow/embed_code/57941706'
  end

  def test_show_with_google_docs_macro
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    @page.content.text = '{{google_docs(https://docs.google.com/spreadsheets/d/e/RANDOMCODE/pubhtml)}}'
    @page.content.save!
    get :show,
        params: { project_id: 1, id: @page_name }
    assert_response :success
    assert_select 'iframe[src=?]', 'https://docs.google.com/spreadsheets/d/e/RANDOMCODE/pubhtml?widget=true&headers=false'
  end

  def test_show_with_iframe_macro
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    @page.content.text = '{{iframe(https://www.redmine.org/)}}'
    @page.content.save!
    get :show,
        params: { project_id: 1, id: @page_name }
    assert_response :success
    assert_select 'iframe[src=?]', 'https://www.redmine.org/'
  end

  def test_show_with_twitter_macro
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    @page.content.text = '{{twitter(alphanodes)}}'
    @page.content.save!
    get :show,
        params: { project_id: 1, id: @page_name }
    assert_response :success
    assert_select 'a.twitter'
    assert_select 'a[href=?]', 'https://twitter.com/alphanodes',
                  text: '@alphanodes'

    @page.content.text = '{{twitter(@alphanodes)}}'
    @page.content.save!
    get :show,
        params: { project_id: 1, id: @page_name }
    assert_select 'a.twitter'
    assert_select 'a[href=?]', 'https://twitter.com/alphanodes',
                  text: '@alphanodes'

    @page.content.text = '{{twitter(#alphanodes)}}'
    @page.content.save!
    get :show,
        params: { project_id: 1, id: @page_name }
    assert_select 'a.twitter'
    assert_select 'a[href=?]', 'https://twitter.com/hashtag/alphanodes',
                  text: '#alphanodes'
  end

  def test_show_with_reddit_macro
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    @page.content.text = '{{reddit(redmine)}}'
    @page.content.save!
    get :show,
        params: { project_id: 1, id: @page_name }
    assert_response :success
    assert_select 'a.reddit'
    assert_select 'a[href=?]', 'https://www.reddit.com/r/redmine',
                  text: 'r/redmine'

    @page.content.text = '{{reddit(u/redmine)}}'
    @page.content.save!
    get :show,
        params: { project_id: 1, id: @page_name }
    assert_select 'a.reddit'
    assert_select 'a[href=?]', 'https://www.reddit.com/username/redmine',
                  text: 'u/redmine'

    @page.content.text = '{{reddit(r/redmine)}}'
    @page.content.save!
    get :show,
        params: { project_id: 1, id: @page_name }
    assert_select 'a.reddit'
    assert_select 'a[href=?]', 'https://www.reddit.com/r/redmine',
                  text: 'r/redmine'
  end

  def test_show_last_updated_by_macro
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    @page.content.text = '{{last_updated_by}}'
    @page.content.save!
    get :show,
        params: { project_id: 1, id: @page_name }
    assert_response :success
    assert_select 'span.last-updated-by'
    assert_select 'a[href=?]', '/users/2',
                  text: 'jsmith'
  end

  def test_show_last_updated_at_macro
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    @page.content.text = '{{last_updated_at}}'
    @page.content.save!
    get :show,
        params: { project_id: 1, id: @page_name }
    assert_response :success
    assert_select 'span.last-updated-at'
    assert_select 'a[href=?]', '/projects/ecookbook/activity'
  end

  def test_show_recently_updated_macro
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    @page.content.text = '{{recently_updated}}'
    @page.content.save!
    get :show,
        params: { project_id: 1, id: @page_name }
    assert_response :success
    assert_select 'div.recently-updated'
  end

  def test_show_with_members_macro
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    @page.content.text = '{{members}}'
    @page.content.save!
    get :show,
        params: { project_id: 1, id: @page_name }
    assert_response :success
    assert_select 'div.wiki div.user'
  end

  def test_show_with_new_issue_macro
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    @page.content.text = '{{new_issue}}'
    @page.content.save!
    get :show,
        params: { project_id: 1, id: @page_name }
    assert_response :success
    assert_select 'div.wiki a.macro-new-issue'
  end

  def test_show_with_group_users_macro
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    @page.content.text = '{{group_users(A Team)}}'
    @page.content.save!
    get :show,
        params: { project_id: 1, id: @page_name }
    assert_response :success
    assert_select 'div.wiki div.user'
  end

  def test_show_with_projects_macro
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    @page.content.text = '{{projects}}'
    @page.content.save!
    get :show,
        params: { project_id: 1, id: @page_name }
    assert_response :success
    assert_select 'div.wiki div.additionals-projects tr.project'
  end

  def test_show_with_fa_macro
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    @page.content.text = '{{fa(adjust)}}'
    @page.content.save!
    get :show,
        params: { project_id: 1, id: @page_name }
    assert_response :success
    assert_select 'i.fas.fa-adjust'
  end

  def test_show_with_redmine_issue_macro
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    @page.content.text = '{{redmine_issue(12066)}}'
    @page.content.save!
    get :show,
        params: { project_id: 1, id: @page_name }
    assert_response :success
    assert_select 'a[href=?]', 'https://www.redmine.org/issues/12066'
  end

  def test_show_with_redmine_issue_with_absolute_url_macro
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    @page.content.text = '{{redmine_issue(http://www.redmine.org/issues/12066)}}'
    @page.content.save!
    get :show,
        params: { project_id: 1, id: @page_name }
    assert_response :success
    assert_select 'a[href=?]', 'https://www.redmine.org/issues/12066'
  end

  def test_show_with_redmine_wiki_macro
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    @page.content.text = '{{redmine_wiki(RedmineInstall)}}'
    @page.content.save!
    get :show,
        params: { project_id: 1, id: @page_name }
    assert_response :success
    assert_select 'a[href=?]', 'https://www.redmine.org/projects/redmine/wiki/RedmineInstall'
  end

  def test_show_with_redmine_wiki_with_absolute_url_macro
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    @page.content.text = '{{redmine_wiki(http://www.redmine.org/projects/redmine/wiki/RedmineInstall)}}'
    @page.content.save!
    get :show,
        params: { project_id: 1, id: @page_name }
    assert_response :success
    assert_select 'a[href=?]', 'https://www.redmine.org/projects/redmine/wiki/RedmineInstall'
  end

  def test_show_with_gist_macro
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    @page.content.text = '{{gist(plentz/6737338)}}'
    @page.content.save!
    get :show,
        params: { project_id: 1, id: @page_name }
    assert_response :success
    assert_select 'script[src=?]', 'https://gist.github.com/plentz/6737338.js'
  end

  def test_show_with_tradeview_macro
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    @page.content.text = '{{tradingview(symbol=NASDAQ:AMZN, locale=en)}}'
    @page.content.save!
    get :show,
        params: { project_id: 1, id: @page_name }
    assert_response :success
    assert_select 'script[src=?]', 'https://s3.tradingview.com/tv.js'
  end

  def test_show_with_cryptocompare_macro
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    @page.content.text = '{{cryptocompare(fsyms=BTC;ETH, type=header_v3)}}'
    @page.content.save!
    get :show,
        params: { project_id: 1, id: @page_name }
    assert_response :success
    assert_select 'div.wiki div.cryptocompare',
                  text: %r{https://widgets\.cryptocompare\.com/serve/v3/coin/header\?fsyms=BTC,ETH&tsyms=EUR}
  end

  def test_show_with_date_macro
    @request.session[:user_id] = WIKI_MACRO_USER_ID

    valid_types = %w[current_date current_date_with_time current_year
                     current_month current_day current_hour current_minute
                     current_weekday current_weeknumber]

    @page.content.text = ''
    valid_types.each do |type|
      @page.content.text << "{{date(#{type})}}"
    end
    @page.content.save!

    get :show,
        params: { project_id: 1, id: @page_name }

    assert_response :success
    assert_select 'div.wiki', html: /{{date/, count: 0
    assert_select 'div.wiki span.current-date', count: valid_types.count
    assert_select 'div.wiki span.current-date', User.current.today.cweek.to_s
    assert_select 'div.flash.error', html: /Error executing/, count: 0
  end

  def test_show_with_date_macro_and_invalid_type
    @request.session[:user_id] = WIKI_MACRO_USER_ID

    @page.content.text = '{{date(invalid_type_name)}}'
    @page.content.save!

    get :show,
        params: { project_id: 1, id: @page_name }

    assert_response :success
    assert_select 'div.flash.error', html: /Error executing/
  end

  def test_show_with_date_macro_custom_date
    @request.session[:user_id] = WIKI_MACRO_USER_ID

    @page.content.text = '{{date(2017-02-25)}}'
    @page.content.save!

    get :show,
        params: { project_id: 1, id: @page_name }

    assert_response :success
    assert_select 'div.flash.error', html: /Error executing/, count: 0
  end

  def test_show_with_date_macro_invalid_custom_date
    @request.session[:user_id] = WIKI_MACRO_USER_ID

    @page.content.text = '{{date(2017-02-30)}}'
    @page.content.save!

    get :show,
        params: { project_id: 1, id: @page_name }

    assert_response :success
    assert_select 'div.flash.error', html: /Error executing/
  end

  def test_show_with_asciinema_macro
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    @page.content.text = '{{asciinema(113463)}}'
    @page.content.save!
    get :show,
        params: { project_id: 1, id: @page_name }
    assert_response :success
    assert_select 'script[src=?]', '//asciinema.org/a/113463.js'
  end

  def test_show_issue
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    @page.content.text = '{{issue(2, format=short)}}'
    @page.content.save!
    get :show,
        params: { project_id: 1, id: @page_name }
    assert_response :success
    assert_select 'a[href=?]', '/issues/2',
                  text: 'Add ingredients categories'
  end

  def test_show_issue_with_id
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    @page.content.text = '{{issue(2, format=link)}}'
    @page.content.save!
    get :show,
        params: { project_id: 1, id: @page_name }
    assert_response :success
    assert_select 'a[href=?]', '/issues/2',
                  text: '#2 Add ingredients categories'
  end

  def test_show_issue_with_url
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    @page.content.text = '{{issue(http://test.host/issues/2)}}'
    @page.content.save!
    get :show,
        params: { project_id: 1, id: @page_name }
    assert_response :success
    assert_select 'a[href=?]', '/issues/2',
                  text: '#2 Add ingredients categories'
    assert_select 'div.issue-macro-comment', 0
  end

  def test_show_issue_and_comment_with_url
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    @page.content.text = '{{issue(http://test.host/issues/2#note-1)}}'
    @page.content.save!
    get :show,
        params: { project_id: 1, id: @page_name }
    assert_response :success
    assert_select 'a[href=?]', '/issues/2',
                  text: '#2 Add ingredients categories'
    assert_select 'div.issue-macro-comment'
  end

  def test_show_issue_with_id_default
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    @page.content.text = '{{issue(2)}}'
    @page.content.save!
    get :show,
        params: { project_id: 1, id: @page_name }
    assert_response :success
    assert_select 'a[href=?]', '/issues/2',
                  text: '#2 Add ingredients categories'
  end

  def test_show_user_with_current_user
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    @page.content.text = '{{user(current_user)}}'
    @page.content.save!
    get :show,
        params: { project_id: 1, id: @page_name }
    assert_response :success
    assert_select '#content a.user.active[href=?]', '/users/2',
                  text: 'John Smith'
  end

  def test_show_user_with_current_user_as_text
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    @page.content.text = '{{user(current_user, text=true)}}'
    @page.content.save!
    get :show,
        params: { project_id: 1, id: @page_name }
    assert_response :success
    assert_select '#content span.user.active', text: 'John Smith'
  end

  def test_show_user_with_id
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    @page.content.text = '{{user(1)}}'
    @page.content.save!
    get :show,
        params: { project_id: 1, id: @page_name }
    assert_response :success
    assert_select '#content a[href=?]', '/users/1',
                  text: 'Redmine Admin'
  end

  def test_show_user_with_id_fullname
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    @page.content.text = '{{user(1, format=firstname_lastname)}}'
    @page.content.save!
    get :show,
        params: { project_id: 1, id: @page_name }
    assert_response :success
    assert_select '#content a.user', text: 'Redmine Admin'
    assert_select '#content a[href=?]', '/users/1',
                  text: 'Redmine Admin'
  end

  def test_show_user_with_name
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    @page.content.text = '{{user(jsmith)}}'
    @page.content.save!
    get :show,
        params: { project_id: 1, id: @page_name }
    assert_response :success
    assert_select '#content a[href=?]', '/users/2',
                  text: 'John Smith'
  end

  def test_show_user_with_name_fullname
    @request.session[:user_id] = WIKI_MACRO_USER_ID
    @page.content.text = '{{user(jsmith, format=firstname_lastname, avatar=true)}}'
    @page.content.save!
    get :show,
        params: { project_id: 1, id: @page_name }
    assert_response :success
    assert_select '#content a.user', text: 'John Smith'
    assert_select '#content a[href=?]', '/users/2',
                  text: 'John Smith'
  end
end
