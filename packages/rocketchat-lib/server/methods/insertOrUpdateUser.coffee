Meteor.methods
	insertOrUpdateUser: (userData) ->
		if not Meteor.userId()
			throw new Meteor.Error('invalid-user', "[methods] updateUser -> Invalid user")

		user = Meteor.user()

		canEditUser = RocketChat.authz.hasPermission( user._id, 'edit-other-user-info')
		canAddUser = RocketChat.authz.hasPermission( user._id, 'add-user')

		if userData._id and user._id isnt userData._id and canEditUser isnt true
			throw new Meteor.Error 'not-authorized', '[methods] updateUser -> Not authorized'

		if not userData._id and canAddUser isnt true
			throw new Meteor.Error 'not-authorized', '[methods] updateUser -> Not authorized'

		unless userData.name
			throw new Meteor.Error 'name-is-required', 'Name field is required'

		unless userData.username
			throw new Meteor.Error 'user-name-is-required', 'Username field is required'

		if not userData._id and not userData.password
			throw new Meteor.Error 'password-is-required', 'Password is required when adding a user'

		if not userData._id
			if not RocketChat.checkUsernameAvailability userData.username
				throw new Meteor.Error 'username-unavailable', "#{userData.username} is already in use :("

			if userData.email and not RocketChat.checkEmailAvailability userData.email
				throw new Meteor.Error 'email-unavailable', "#{userData.email} is already in use :("

			# insert user
			createUser = { username: userData.username, password: userData.password }
			if userData.email
				createUser.email = userData.email

			_id = Accounts.createUser(createUser)
			if userData.requirePasswordChange
				Meteor.users.update { _id: _id }, { $set: { name: userData.name, requirePasswordChange: userData.requirePasswordChange } }

			return _id
		else
			#update user
			Meteor.users.update { _id: userData._id }, { $set: { name: userData.name, requirePasswordChange: userData.requirePasswordChange } }

			Meteor.runAsUser userData._id, ->
				Meteor.call 'setUsername', userData.username

			canEditUserPassword = RocketChat.authz.hasPermission( user._id, 'edit-other-user-password')
			if canEditUserPassword and userData.password.trim()
				Accounts.setPassword userData._id, userData.password.trim()

			return true