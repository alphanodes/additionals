# frozen_string_literal: true

module CrudControllerBase
  extend ActiveSupport::Concern

  included do
    # Show

    def test_show
      unless prepare_crud_test :show
        # no controller action should be available, test it
        assert_raises ActionController::UrlGenerationError do
          get :show
        end
        return
      end

      get :show, params: @crud[:show_params].presence || { id: @crud[:entity].id }

      if @crud[:show_assert_response].present?
        assert_response @crud[:show_assert_response]
      else
        assert_response :success
      end

      assert_select(*@crud[:show_assert_select]) if @crud[:show_assert_select].present?
    end

    def test_show_without_permission
      return unless prepare_crud_test :show, no_permission: true

      get :show, params: @crud[:show_params].presence || { id: @crud[:entity].id }
      assert_response :forbidden
    end

    # Index

    def test_index
      unless prepare_crud_test :index
        # no controller action should be available, test it
        assert_raises ActionController::UrlGenerationError do
          get :index
        end
        return
      end

      get :index, params: @crud[:index_params]

      if @crud[:index_assert_response].present?
        assert_response @crud[:index_assert_response]
      else
        assert_response :success
      end
      assert_select(*@crud[:index_assert_select]) if @crud[:index_assert_select].present?
    end

    def test_index_without_permission
      return unless prepare_crud_test :index, no_permission: true

      get :index, params: @crud[:index_params]

      if @crud[:index_forbitten_status].present?
        assert_response @crud[:index_forbitten_status]
      else
        assert_response :forbidden
      end
    end

    # New

    def test_new
      unless prepare_crud_test :new
        # no controller action should be available, test it
        assert_raises ActionController::UrlGenerationError do
          get :new
        end
        return
      end

      get :new, params: @crud[:new_params].presence || {}
      assert_response :success
    end

    def test_new_without_permission
      return unless prepare_crud_test :new, no_permission: true

      get :new, params: @crud[:new_params].presence || {}
      assert_response :forbidden
    end

    # Create

    def test_create
      unless prepare_crud_test :create
        # no controller action should be available, test it
        assert_raises ActionController::UrlGenerationError do
          post :create
        end
        return
      end

      assert_difference "#{@crud[:entity].class.name}.count" do
        assert_no_difference 'Journal.count' do
          post :create, params: form_params(:create)
        end
      end

      if @crud[:create_redirect_to]
        assert_redirected_to @crud[:create_redirect_to]
      else
        assert_response 302
      end

      entity = @crud[:entity].class.order(id: :desc).first

      if @crud[:created_assert].present?
        @crud[:created_assert].each do |name|
          assert entity.send(name), "Expected false to be truthy for #{name}"
        end
      end

      if @crud[:create_assert_not].present?
        @crud[:create_assert_not].each do |name|
          assert_not entity.send(name), "Expected true to be nil or false for #{name}"
        end
      end

      return if @crud[:create_assert_equals].blank?

      @crud[:create_assert_equals].each do |name, value|
        assert_equal value, entity.send(name)
      end
    end

    def test_create_without_permission
      return unless prepare_crud_test :create, no_permission: true

      assert_no_difference "#{@crud[:entity].class.name}.count" do
        post :create, params: form_params(:create)
      end

      assert_response :forbidden
    end

    # Edit

    def test_edit
      unless prepare_crud_test :edit
        # no controller action should be available, test it
        assert_raises ActionController::UrlGenerationError do
          post :edit
        end
        return
      end

      get :edit, params: { id: @crud[:entity].id }

      assert_response :success
      if @crud[:edit_assert_select].present?
        assert_select(*@crud[:edit_assert_select])
      else
        assert_select "form#edit_#{@crud[:form]}"
      end
    end

    def test_edit_without_permission
      return unless prepare_crud_test :edit, no_permission: true

      get :edit, params: { id: @crud[:entity].id }

      assert_response :forbidden
    end

    # Update

    def test_update
      unless prepare_crud_test :update
        # no controller action should be available, test it
        assert_raises ActionController::UrlGenerationError do
          put :update
        end
        return
      end

      put :update, params: form_params(:update)

      if @crud[:update_redirect_to]
        assert_redirected_to @crud[:update_redirect_to]
      else
        assert_response 302
      end

      @crud[:entity].reload

      if @crud[:update_assert].present?
        @crud[:update_assert].each do |name|
          assert @crud[:entity].send(name), "Expected false to be truthy for #{name}"
        end
      end

      if @crud[:update_assert_not].present?
        @crud[:update_assert_not].each do |name|
          assert_not @crud[:entity].send(name), "Expected true to be nil or false for #{name}"
        end
      end

      return if @crud[:update_assert_equals].blank?

      @crud[:update_assert_equals].each do |name, value|
        assert_equal value, @crud[:entity].send(name)
      end
    end

    def test_update_without_permission
      return unless prepare_crud_test :update, no_permission: true

      put :update, params: form_params(:update)

      assert_response :forbidden

      return if @crud[:update_equals].blank?

      @crud[:entity].reload
      @crud[:update_equals].each do |name, value|
        assert_not_equal value, @crud[:entity].send(name)
      end
    end

    # Delete

    def test_delete
      unless prepare_crud_test :delete
        # no controller action should be available, test it
        assert_raises ActionController::UrlGenerationError do
          delete :destroy
        end
        return
      end

      assert_difference("#{@crud[:entity].class.name}.count", -1) do
        delete :destroy, params: { id: @crud[:entity].id }
      end

      return if @crud[:delete_redirect_to].blank?

      assert_redirected_to @crud[:delete_redirect_to]
    end

    def test_delete_without_permission
      return unless prepare_crud_test :delete, no_permission: true

      assert_no_difference "#{@crud[:entity].class.name}.count" do
        delete :destroy, params: { id: @crud[:entity].id }
      end

      assert_response :forbidden
    end

    private

    def form_params(action)
      crud_params = @crud["#{action}_params".to_sym]
      if @crud[:form]
        { id:  @crud[:entity].id, @crud[:form] => crud_params }
      else
        crud_params
      end
    end

    def prepare_crud_test(action, no_permission: false)
      return false if @crud[:without_actions].present? && @crud[:without_actions].include?(action)

      @request.session[:user_id] = if no_permission
                                     @user_without_permission.id
                                   else
                                     @user.id
                                   end
      true
    end
  end
end
