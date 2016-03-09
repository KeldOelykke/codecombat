RootView = require 'views/core/RootView'
template = require 'templates/courses/teacher-class-view'
helper = require 'lib/coursesHelper'
InviteToClassroomModal = require 'views/courses/InviteToClassroomModal'

Classroom = require 'models/Classroom'
LevelSessions = require 'collections/LevelSessions'
Users = require 'collections/Users'
Courses = require 'collections/Courses'
CourseInstances = require 'collections/CourseInstances'
Campaigns = require 'collections/Campaigns'

module.exports = class TeacherClassView extends RootView
  id: 'teacher-class-view'
  template: template
  
  events:
    'click .add-students-button': 'onClickAddStudents'
    'click .sort-by-name': 'sortByName'
    'click .sort-by-progress': 'sortByProgress'

  initialize: (options, classroomID) ->
    super(options)
    @sortAttribute = 'name'
    @sortDirection = 1
    
    @classroom = new Classroom({ _id: classroomID })
    @classroom.fetch()
    @supermodel.trackModel(@classroom)
    
    @listenTo @classroom, 'sync', ->
      @students = new Users()
      @students.fetchForClassroom(@classroom)
      @supermodel.trackCollection(@students)
      @listenTo @students, 'sync', @sortByName
      @listenTo @students, 'sort', @render
      
      @classroom.sessions = new LevelSessions()
      @classroom.sessions.fetchForAllClassroomMembers(@classroom)
      @supermodel.trackCollection(@classroom.sessions)
      
    @courses = new Courses()
    @courses.fetch()
    @supermodel.trackCollection(@courses)
    
    @campaigns = new Campaigns()
    @campaigns.fetchByType('course')
    @supermodel.trackCollection(@campaigns)
    
    @courseInstances = new CourseInstances()
    @courseInstances.fetchByOwner(me.id)
    @supermodel.trackCollection(@courseInstances)
    

  onLoaded: ->
    console.log("loaded!")
    @earliestIncompleteLevel = helper.calculateEarliestIncomplete(@classroom, @courses, @campaigns, @courseInstances, @students)
    @latestCompleteLevel = helper.calculateLatestComplete(@classroom, @courses, @campaigns, @courseInstances, @students)
    for student in @students.models
      # TODO: this is a weird hack
      studentsStub = { models: [student], _byId: {} }
      studentsStub._byId[student.id] = student
      student.latestCompleteLevel = helper.calculateLatestComplete(@classroom, @courses, @campaigns, @courseInstances, studentsStub)
      
    classroomsStub = { models: [@classroom] }
    @progressData = helper.calculateAllProgress(classroomsStub, @courses, @campaigns, @courseInstances, @students)
    super()

  onClickAddStudents: (e) =>
    modal = new InviteToClassroomModal({ classroom: @classroom })
    @openModalView(modal)
    @listenToOnce modal, 'hide', @render
    
  sortByName: (e) =>
    if @sortValue == 'name'
      @sortDirection = -@sortDirection
    else
      @sortValue = 'name'
      @sortDirection = 1
      
    dir = @sortDirection
    @students.comparator = (student1, student2) ->
      return (if student1.get('name') < student2.get('name') then -dir else dir)
    @students.sort()
    
  sortByProgress: (e) =>
    if @sortValue == 'progress'
      @sortDirection = -@sortDirection
    else
      @sortValue = 'progress'
      @sortDirection = 1
      
    dir = @sortDirection
    @students.comparator = (student1, student2) ->
      l1 = student1.latestCompleteLevel
      l2 = student2.latestCompleteLevel
      if l1.courseNumber < l2.courseNumber
        return -dir
      else if l1.levelNumber < l2.levelNumber
        return -dir
      else
        return dir
    @students.sort()
    
  getProgress: (options = {}) ->
    return helper.getProgress(@progressData, _.extend({ classroom: @classroom }, options))
