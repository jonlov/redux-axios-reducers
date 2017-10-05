Axios = require('axios')

class AxiosReducer

  default:
    data: null
    error: null
    fetching: null

  # Construct types and configuration
  constructor: (@config={}) ->
    @config.name ?= 'noname'
    @config.baseURL ?= "/#{@config.name}"
    @default = {@default...}

    name = @config.name.toUpperCase()
    @TYPES = {
      FETCHING: "ASYNC/#{name}/FETCHING"
      FETCH_FAIL: "ASYNC/#{name}/FETCH_FAIL"
      FETCH_SUCCESS: "ASYNC/#{name}/FETCH_SUCCESS"
    }

    # Init reducer
  configure: (@axios, config) ->

    selfState = null

    @getState = -> {selfState...}

    @config = {@config..., config...} if config

    # Create Reducer
    return (state=@default, action) =>
      return selfState = switch action.type

        when @TYPES.FETCHING
          {state..., @reduceFetching(state, action)...}

        when @TYPES.FETCH_SUCCESS
          {state..., @reduceSuccess(state, action)...}

        when @TYPES.FETCH_FAIL
          {state..., @reduceFail(state, action)...}

        else state

  reduceFetching: -> fetching: true

  reduceSuccess: (state, action) ->
    return
      data: action.response.data
      fetching: false
      error: null

  reduceFail: (state, action) ->
    return
      error: action.error
      fetching: false

  request: (config) =>

    unless @axios and @axios.request
      throw new Error(
        "Please configure the reducer '#{@config.name}' before first use.")

    return @axios.request(config)

  fetch: (config={}) => (dispatch) =>

    config = @transformConfig(config)

    cancel = null
    config = {config..., cancelToken: new Axios.CancelToken(
      (c) -> cancel = c
    )}

    dispatch type: @TYPES.FETCHING, config: config

    promise = @request(config)

      .then (response) =>
        response.data = @transformData(response.data)
        dispatch
          type: @TYPES.FETCH_SUCCESS
          config: config
          response: response

        return response

      .catch (error) =>
        console?.error(error)
        dispatch
          type: @TYPES.FETCH_FAIL
          config: config
          error: if Axios.isCancel(error) then null else error

        return error

    promise.cancel = cancel
    return promise

  update: (config) =>
    return @put(config) if config.data and config.data.id or config.id
    return @post(config)

  get: (config) => @fetch(config)

  post: (config={}) =>
    config = {data: config} unless config.data
    config = {config..., method: config.method or 'post'}
    @fetch(config)

  put: (config={}) =>
    config = {data: config} unless config.data
    config = {config..., method: config.method or 'put'}
    @fetch(config)

  patch: (config={}) =>
    config = {data: config} unless config.data
    config = {config..., method: config.method or 'patch'}
    @fetch(config)

  remove: (config={}) =>
    config = {config..., method: config.method or 'delete'}
    @fetch(config)

  transformConfig: (config) ->
    return {
      config...,
      method: config.method or 'get'
      url: config.url or @config.baseURL}

  transformData: (data) -> data


class AxiosRESTReducer extends AxiosReducer

  constructor: (config) ->
    super(config)

    @default.byId = {}
    @default.data = []

  reduceSuccess: (state, action) ->
    singleId = action.config.id or (
      action.config.data and action.config.data.id)

    state.data = [] if action.config.method == 'get' and not singleId
    data = action.response.data
    data = [data] unless Array.isArray(data)

    for item in data
      continue unless item and item.id
      state.byId[item.id] = item
      state.data.push(item.id) unless singleId

    if action.config.method == 'delete' and singleId
      delete state.byId[singleId]
      state.data = (id for id in state.data when id != singleId)

    return fetching: false, error: null

  transformConfig: (config) ->
    config = super(config)
    id = (
      config.id or (config.data and config.data.id) or
      (config.params and config.params.id))
    config.url += "/#{id}" if id
    return config

  # Iterate through loaded data
  iterate: =>
    state = @getState()
    return [] unless state.data
    return (state.byId[id] for id in state.data)

module.exports = { AxiosReducer, AxiosRESTReducer }
