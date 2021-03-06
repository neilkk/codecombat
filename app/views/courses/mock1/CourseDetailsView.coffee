app = require 'core/application'
RootView = require 'views/core/RootView'
template = require 'templates/courses/mock1/course-details'
CocoCollection = require 'collections/CocoCollection'
Campaign = require 'models/Campaign'

module.exports = class CourseDetailsView extends RootView
  id: 'course-details-view'
  template: template

  events:
    'change .expand-progress-checkbox': 'onExpandedProgressCheckbox'
    'change .select-session': 'onChangeSession'
    'change .student-mode-checkbox': 'onChangeStudent'
    'click .edit-class-name-btn': 'onClickEditClassName'
    'click .edit-description-btn': 'onClickEditClassDescription'
    'click .btn-play-level': 'onClickPlayLevel'

  constructor: (options, @courseID) ->
    super options
    @initData()

  destroy: ->
    @stopListening?()

  getRenderData: ->
    context = super()
    context.conceptsProgression = @conceptsProgression ? []
    context.course = @course ? {}
    context.courseConcepts = @courseConcepts ? []
    context.instance = @instances?[@currentInstanceIndex] ? {}
    context.instances = @instances ? []
    context.levelConceptsMap = @levelConceptsMap ? {}
    context.maxLastStartedIndex = @maxLastStartedIndex ? 0
    context.userConceptsMap = @userConceptsMap ? {}
    context.userLevelStateMap = @userLevelStateMap ? {}
    context.showExpandedProgress = @course.levels.length <= 30 or @showExpandedProgress
    context.studentMode = @studentMode ? false
    context

  initData: ->
    mockData = require 'views/courses/mock1/CoursesMockData'
    @course = mockData.courses[@courseID]
    @currentInstanceIndex = 0
    @instances = mockData.instances
    @updateLevelMaps()

    @campaigns = new CocoCollection([], { url: "/db/campaign", model: Campaign, comparator:'_id' })
    @listenTo @campaigns, 'sync', @onCampaignSync
    @supermodel.loadModel @campaigns, 'clan', cache: false

  updateLevelMaps: ->
    @levelMap = {}
    @levelMap[level] = true for level in @course.levels
    @userLevelStateMap = {}
    @maxLastStartedIndex = -1
    for student in @instances?[@currentInstanceIndex].students
      @userLevelStateMap[student] = {}
      lastCompletedIndex = _.random(0, @course.levels.length)
      for i in [0..lastCompletedIndex]
        @userLevelStateMap[student][@course.levels[i]] = 'complete'
      lastStartedIndex = lastCompletedIndex + 1
      @userLevelStateMap[student][@course.levels[lastStartedIndex]] = 'started'
      @maxLastStartedIndex = lastStartedIndex if lastStartedIndex > @maxLastStartedIndex

  onCampaignSync: ->
    return unless @campaigns.loaded
    @conceptsProgression = []
    @courseConcepts = []
    @levelConceptsMap = {}
    @levelNameSlugMap = {}
    @userConceptsMap = {}
    for campaign in @campaigns.models
      continue if campaign.get('slug') is 'auditions'
      for levelID, level of campaign.get('levels')
        @levelNameSlugMap[level.name] = level.slug
        if level.concepts?
          for concept in level.concepts
            @conceptsProgression.push concept unless concept in @conceptsProgression
            continue unless @levelMap[level.name]
            @courseConcepts.push concept unless concept in @courseConcepts
            @levelConceptsMap[level.name] ?= {}
            @levelConceptsMap[level.name][concept] = true
            for student in @instances?[@currentInstanceIndex].students
              @userConceptsMap[student] ?= {}
              if @userLevelStateMap[student][level.name] is 'complete'
                @userConceptsMap[student][concept] = 'complete'
              else if @userLevelStateMap[student][level.name] is 'started'
                @userConceptsMap[student][concept] ?= 'started'
    @courseConcepts.sort (a, b) => if @conceptsProgression.indexOf(a) < @conceptsProgression.indexOf(b) then -1 else 1
    @render?()

  onChangeStudent: (e) ->
    @studentMode = $('.student-mode-checkbox').prop('checked')
    @render?()
    $('.student-mode-checkbox').attr('checked', @studentMode)

  onChangeSession: (e) ->
    @showExpandedProgress = false
    newSessionValue = $(e.target).val()
    for val, index in @instances when val.name is newSessionValue
      @currentInstanceIndex = index
    @updateLevelMaps()
    @render?()

  onExpandedProgressCheckbox: (e) ->
    @showExpandedProgress = $('.expand-progress-checkbox').prop('checked')
    # TODO: why does render reset the checkbox to be unchecked?
    @render?()
    $('.expand-progress-checkbox').attr('checked', @showExpandedProgress)

  onClickEditClassName: (e) ->
    alert 'TODO: Popup for editing name for this course session'

  onClickEditClassDescription: (e) ->
    alert 'TODO: Popup for editing description for this course session'

  onClickPlayLevel: (e) ->
    levelName = $(e.target).data('level')
    levelSlug = @levelNameSlugMap[levelName]
    Backbone.Mediator.publish 'router:navigate', {
      route: "/play/level/#{levelSlug}"
      viewClass: 'views/play/level/PlayLevelView'
      viewArgs: [{}, levelSlug]
    }
