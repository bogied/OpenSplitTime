require 'rails_helper'

describe Api::V1::UsersController do
  login_admin

  let(:user) { FactoryGirl.create(:user) }

  describe '#show' do
    it 'returns a successful 200 response' do
      get :show, id: user
      expect(response).to be_success
    end

    it 'returns data of a single user' do
      get :show, id: user
      parsed_response = JSON.parse(response.body)
      expect(parsed_response['id']).to eq(user.id)
    end

    it 'returns an error if the user does not exist' do
      get :show, id: 0
      parsed_response = JSON.parse(response.body)
      expect(parsed_response['message']).to match(/not found/)
      expect(response).to be_not_found
    end
  end

  describe '#create' do
    it 'returns a successful json response' do
      post :create, user: {first_name: 'Test', last_name: 'User', email: 'test_user@example.com', password: 'password'}
      parsed_response = JSON.parse(response.body)
      expect(parsed_response['id']).not_to be_nil
      expect(response).to be_success
    end

    it 'creates a user record' do
      expect(User.all.count).to eq(1)
      post :create, user: {first_name: 'Test', last_name: 'User', email: 'test_user@example.com', password: 'password'}
      expect(User.all.count).to eq(2)
    end
  end

  describe '#update' do
    let(:attributes) { {first_name: 'Updated First Name', pref_distance_unit: 'kilometers', pref_elevation_unit: 'meters'} }

    it 'returns a successful json response' do
      put :update, id: user, user: attributes
      expect(response).to be_success
    end

    it 'updates the specified fields' do
      put :update, id: user, user: attributes
      user.reload
      expect(user.first_name).to eq(attributes[:first_name])
      expect(user.pref_distance_unit).to eq(attributes[:pref_distance_unit])
      expect(user.pref_elevation_unit).to eq(attributes[:pref_elevation_unit])
    end

    it 'returns an error if the user does not exist' do
      put :update, id: 0, user: attributes
      parsed_response = JSON.parse(response.body)
      expect(parsed_response['message']).to match(/not found/)
      expect(response).to be_not_found
    end
  end

  describe '#destroy' do
    it 'returns a successful json response' do
      delete :destroy, id: user
      expect(response).to be_success
    end

    it 'destroys the user record' do
      test_user = user
      expect(User.all.count).to eq(2)
      delete :destroy, id: test_user
      expect(User.all.count).to eq(1)
    end

    it 'returns an error if the user does not exist' do
      delete :destroy, id: 0
      parsed_response = JSON.parse(response.body)
      expect(parsed_response['message']).to match(/not found/)
      expect(response).to be_not_found
    end
  end

  describe '#current' do
    it 'returns a successful json response' do
      get :current
      expect(response).to be_success
    end

    it 'returns data of the current user' do
      get :current
      parsed_response = JSON.parse(response.body)
      expect(parsed_response['id']).to eq(subject.current_user.id)
    end
  end
end