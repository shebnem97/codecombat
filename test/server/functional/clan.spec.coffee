config = require '../../../server_config'
require '../common'
utils = require '../../../app/core/utils' # Must come after require /common
mongoose = require 'mongoose'

describe 'Clans', ->
  stripe = require('stripe')(config.stripe.secretKey)
  clanURL = getURL('/db/clan')

  clanCount = 0
  createClanName = (name) -> name + clanCount++

  createClan = (type, done) ->
    name = createClanName 'myclan'
    requestBody =
      type: type
      name: name
    request.post {uri: clanURL, json: requestBody }, (err, res, body) ->
      expect(err).toBeNull()
      expect(res.statusCode).toBe(200)
      expect(body.type).toEqual(type)
      expect(body.name).toEqual(name)
      Clan.findById body._id, (err, clan) ->
        expect(clan.get('type')).toEqual(type)
        expect(clan.get('name')).toEqual(name)
        done(clan)

  it 'Clear database users and clans', (done) ->
    clearModels [User, Clan], (err) ->
      throw err if err
      done()

  it 'Create clan', (done) ->
    loginNewUser (user1) ->
      createClan 'public', (clan) ->
        done()

  it 'Anonymous create clan 401', (done) ->
    logoutUser ->
      requestBody =
        type: 'public'
        name: createClanName 'myclan'
      request.post {uri: clanURL, json: requestBody }, (err, res, body) ->
        expect(err).toBeNull()
        expect(res.statusCode).toBe(401)
        done()

  it 'Create clan missing type 422', (done) ->
    loginNewUser (user1) ->
      requestBody =
        name: createClanName 'myclan'
      request.post {uri: clanURL, json: requestBody }, (err, res, body) ->
        expect(err).toBeNull()
        expect(res.statusCode).toBe(422)
        done()

  it 'Create clan missing name 422', (done) ->
    loginNewUser (user1) ->
      requestBody =
        type: 'public'
      request.post {uri: clanURL, json: requestBody }, (err, res, body) ->
        expect(err).toBeNull()
        expect(res.statusCode).toBe(422)
        done()

  it 'Get clans', (done) ->
    loginNewUser (user1) ->
      createClan 'public', (clan1) ->
        createClan 'public', (clan2) ->
          request.get {uri: clanURL }, (err, res, body) ->
            expect(err).toBeNull()
            expect(res.statusCode).toBe(200)
            expect(body.length).toBeGreaterThan(1)
            done()

  it 'Get clans anonymous', (done) ->
    loginNewUser (user1) ->
      createClan 'public', (clan1) ->
        createClan 'public', (clan2) ->
          logoutUser ->
            request.get {uri: clanURL }, (err, res, body) ->
              expect(err).toBeNull()
              expect(res.statusCode).toBe(200)
              expect(body.length).toBeGreaterThan(1)
              done()

  it 'Join clan', (done) ->
    loginNewUser (user1) ->
      createClan 'public', (clan1) ->
        loginNewUser (user2) ->
          request.put {uri: "#{clanURL}/#{clan1.id}/join" }, (err, res, body) ->
            expect(err).toBeNull()
            expect(res.statusCode).toBe(200)
            Clan.findById clan1.id, (err, clan1) ->
              expect(err).toBeNull()
              expect(_.find clan1.get('members'), (m) -> m.id.equals user2.id).toBeDefined()
              done()

  it 'Join invalid clan 404', (done) ->
    loginNewUser (user1) ->
      createClan 'public', (clan1) ->
        loginNewUser (user2) ->
          request.put {uri: "#{clanURL}/1234/join" }, (err, res, body) ->
            expect(err).toBeNull()
            expect(res.statusCode).toBe(404)
            done()

  it 'Join clan anonymous 401', (done) ->
    loginNewUser (user1) ->
      createClan 'public', (clan1) ->
        logoutUser ->
          request.put {uri: "#{clanURL}/#{clan1.id}/join" }, (err, res, body) ->
            expect(err).toBeNull()
            expect(res.statusCode).toBe(401)
            done()

  it 'Join clan twice 200', (done) ->
    loginNewUser (user1) ->
      createClan 'public', (clan1) ->
        loginNewUser (user2) ->
          request.put {uri: "#{clanURL}/#{clan1.id}/join" }, (err, res, body) ->
            expect(err).toBeNull()
            expect(res.statusCode).toBe(200)
            Clan.findById clan1.id, (err, clan1) ->
              expect(err).toBeNull()
              expect(_.find clan1.get('members'), (m) -> m.id.equals user2.id).toBeDefined()
              request.put {uri: "#{clanURL}/#{clan1.id}/join" }, (err, res, body) ->
                expect(err).toBeNull()
                expect(res.statusCode).toBe(200)
                done()
