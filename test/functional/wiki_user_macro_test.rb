# Redmine Tweaks plugin for Redmine
# Copyright (C) 2013-2016 AlphaNodes GmbH

require File.expand_path('../../test_helper', __FILE__)

# Redmine Tweaks functional tests
class WikiUserMacroTest < ActionController::TestCase
  fixtures :projects,
           :users,
           :roles,
           :members,
           :member_roles,
           :trackers,
           :projects_trackers,
           :enabled_modules,
           :issue_statuses,
           :issues,
           :enumerations,
           :custom_fields,
           :custom_values,
           :custom_fields_trackers,
           :wikis

  def setup
    RedmineTweaks::TestCase.prepare
    EnabledModule.create(project_id: 1, name: 'wiki')
    @project = Project.find(1)
    @wiki = @project.wiki
    @page_name = 'tweaks_macro_test'
    @page = @wiki.find_or_new_page(@page_name)
    @page.content = WikiContent.new
    @page.content.text = 'test'
    @page.save!
  end

  def test_show_user_with_id
    @request.session[:user_id] = 1
    @page.content.text = '{{user(1)}}'
    @page.content.save!
    get :show, project_id: 1, id: @page_name
    assert_response :success
    assert_template 'show'
    assert_select 'a[href=?]', '/users/1',
                  text: 'admin'
  end

  def test_show_user_with_id_fullname
    @request.session[:user_id] = 1
    @page.content.text = '{{user(1, format=firstname_lastname)}}'
    @page.content.save!
    get :show, project_id: 1, id: @page_name
    assert_response :success
    assert_template 'show'
    assert_select 'a.user', text: 'Redmine Admin'
    assert_select 'a[href=?]', '/users/1',
                  text: 'Redmine Admin'
  end

  def test_show_user_with_name
    @request.session[:user_id] = 2
    @page.content.text = '{{user(jsmith)}}'
    @page.content.save!
    get :show, project_id: 1, id: @page_name
    assert_response :success
    assert_template 'show'
    assert_select 'a[href=?]', '/users/2',
                  text: 'jsmith'
  end

  def test_show_user_with_name_fullname
    @request.session[:user_id] = 2
    @page.content.text = '{{user(jsmith, format=firstname_lastname, avatar=true)}}'
    @page.content.save!
    get :show, project_id: 1, id: @page_name
    assert_response :success
    assert_template 'show'
    assert_select 'a.user', text: 'John Smith'
    assert_select 'a[href=?]', '/users/2',
                  text: 'John Smith'
  end
end
