
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title StudyToEarnPlatform
 * @dev A blockchain-based platform that rewards students for completing educational courses
 * @author Blockchain Study-to-Earn Platform Team
 */
contract StudyToEarnPlatform {
    
    // State variables
    address public owner;
    uint256 public totalCourses;
    uint256 public totalStudents;
    uint256 public rewardPool;
    
    // Structs
    struct Course {
        uint256 id;
        string title;
        string description;
        address instructor;
        uint256 rewardAmount;
        uint256 duration; // in days
        bool isActive;
        uint256 totalEnrollments;
    }
    
    struct Student {
        address studentAddress;
        string name;
        uint256 totalCoursesCompleted;
        uint256 totalRewardsEarned;
        bool isRegistered;
    }
    
    struct Enrollment {
        uint256 courseId;
        address student;
        uint256 enrollmentDate;
        uint256 completionDate;
        bool isCompleted;
        bool rewardClaimed;
    }
    
    // Mappings
    mapping(uint256 => Course) public courses;
    mapping(address => Student) public students;
    mapping(bytes32 => Enrollment) public enrollments; // keccak256(courseId, studentAddress) => Enrollment
    mapping(address => uint256[]) public studentCourses; // student => courseIds
    mapping(uint256 => address[]) public courseStudents; // courseId => student addresses
    
    // Events
    event CourseCreated(uint256 indexed courseId, string title, address indexed instructor, uint256 rewardAmount);
    event StudentRegistered(address indexed student, string name);
    event CourseEnrolled(uint256 indexed courseId, address indexed student, uint256 enrollmentDate);
    event CourseCompleted(uint256 indexed courseId, address indexed student, uint256 completionDate);
    event RewardClaimed(address indexed student, uint256 courseId, uint256 rewardAmount);
    event RewardPoolUpdated(uint256 newAmount);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }
    
    modifier onlyRegisteredStudent() {
        require(students[msg.sender].isRegistered, "Student must be registered");
        _;
    }
    
    modifier courseExists(uint256 _courseId) {
        require(_courseId > 0 && _courseId <= totalCourses, "Course does not exist");
        _;
    }
    
    modifier courseActive(uint256 _courseId) {
        require(courses[_courseId].isActive, "Course is not active");
        _;
    }
    
    // Constructor
    constructor() {
        owner = msg.sender;
        totalCourses = 0;
        totalStudents = 0;
        rewardPool = 0;
    }
    
    /**
     * @dev Core Function 1: Create a new course
     * @param _title The title of the course
     * @param _description The description of the course
     * @param _rewardAmount The reward amount in wei for completing the course
     * @param _duration The duration of the course in days
     */
    function createCourse(
        string memory _title,
        string memory _description,
        uint256 _rewardAmount,
        uint256 _duration
    ) external {
        require(bytes(_title).length > 0, "Course title cannot be empty");
        require(_rewardAmount > 0, "Reward amount must be greater than 0");
        require(_duration > 0, "Course duration must be greater than 0");
        
        totalCourses++;
        
        courses[totalCourses] = Course({
            id: totalCourses,
            title: _title,
            description: _description,
            instructor: msg.sender,
            rewardAmount: _rewardAmount,
            duration: _duration,
            isActive: true,
            totalEnrollments: 0
        });
        
        emit CourseCreated(totalCourses, _title, msg.sender, _rewardAmount);
    }
    
    /**
     * @dev Core Function 2: Register as a student and enroll in a course
     * @param _name The name of the student
     * @param _courseId The ID of the course to enroll in
     */
    function registerAndEnrollInCourse(string memory _name, uint256 _courseId) 
        external 
        courseExists(_courseId) 
        courseActive(_courseId) 
    {
        require(bytes(_name).length > 0, "Student name cannot be empty");
        
        // Register student if not already registered
        if (!students[msg.sender].isRegistered) {
            students[msg.sender] = Student({
                studentAddress: msg.sender,
                name: _name,
                totalCoursesCompleted: 0,
                totalRewardsEarned: 0,
                isRegistered: true
            });
            totalStudents++;
            emit StudentRegistered(msg.sender, _name);
        }
        
        // Check if already enrolled
        bytes32 enrollmentKey = keccak256(abi.encodePacked(_courseId, msg.sender));
        require(enrollments[enrollmentKey].student == address(0), "Already enrolled in this course");
        
        // Enroll in course
        enrollments[enrollmentKey] = Enrollment({
            courseId: _courseId,
            student: msg.sender,
            enrollmentDate: block.timestamp,
            completionDate: 0,
            isCompleted: false,
            rewardClaimed: false
        });
        
        // Update mappings
        studentCourses[msg.sender].push(_courseId);
        courseStudents[_courseId].push(msg.sender);
        courses[_courseId].totalEnrollments++;
        
        emit CourseEnrolled(_courseId, msg.sender, block.timestamp);
    }
    
    /**
     * @dev Core Function 3: Complete course and claim reward
     * @param _courseId The ID of the completed course
     */
    function completeCourseAndClaimReward(uint256 _courseId) 
        external 
        onlyRegisteredStudent 
        courseExists(_courseId) 
    {
        bytes32 enrollmentKey = keccak256(abi.encodePacked(_courseId, msg.sender));
        Enrollment storage enrollment = enrollments[enrollmentKey];
        
        require(enrollment.student == msg.sender, "Not enrolled in this course");
        require(!enrollment.isCompleted, "Course already completed");
        require(!enrollment.rewardClaimed, "Reward already claimed");
        
        // Check if minimum time has passed (simplified completion logic)
        uint256 minCompletionTime = enrollment.enrollmentDate + (courses[_courseId].duration * 1 days);
        require(block.timestamp >= minCompletionTime, "Minimum course duration not met");
        
        // Mark course as completed
        enrollment.isCompleted = true;
        enrollment.completionDate = block.timestamp;
        enrollment.rewardClaimed = true;
        
        // Update student stats
        students[msg.sender].totalCoursesCompleted++;
        students[msg.sender].totalRewardsEarned += courses[_courseId].rewardAmount;
        
        // Transfer reward
        uint256 rewardAmount = courses[_courseId].rewardAmount;
        require(rewardPool >= rewardAmount, "Insufficient reward pool");
        
        rewardPool -= rewardAmount;
        payable(msg.sender).transfer(rewardAmount);
        
        emit CourseCompleted(_courseId, msg.sender, block.timestamp);
        emit RewardClaimed(msg.sender, _courseId, rewardAmount);
    }
    
    // Additional utility functions
    
    function addToRewardPool() external payable onlyOwner {
        rewardPool += msg.value;
        emit RewardPoolUpdated(rewardPool);
    }
    
    function getStudentCourses(address _student) external view returns (uint256[] memory) {
        return studentCourses[_student];
    }
    
    function getCourseStudents(uint256 _courseId) external view returns (address[] memory) {
        return courseStudents[_courseId];
    }
    
    function getEnrollmentStatus(uint256 _courseId, address _student) external view returns (
        bool enrolled,
        bool completed,
        bool rewardClaimed,
        uint256 enrollmentDate,
        uint256 completionDate
    ) {
        bytes32 enrollmentKey = keccak256(abi.encodePacked(_courseId, _student));
        Enrollment memory enrollment = enrollments[enrollmentKey];
        
        return (
            enrollment.student != address(0),
            enrollment.isCompleted,
            enrollment.rewardClaimed,
            enrollment.enrollmentDate,
            enrollment.completionDate
        );
    }
    
    function toggleCourseStatus(uint256 _courseId) external courseExists(_courseId) {
        require(msg.sender == courses[_courseId].instructor || msg.sender == owner, 
                "Only instructor or owner can toggle course status");
        courses[_courseId].isActive = !courses[_courseId].isActive;
    }
    
    function withdrawEmergency() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
    
    // View functions for getting platform statistics
    function getPlatformStats() external view returns (
        uint256 _totalCourses,
        uint256 _totalStudents,
        uint256 _rewardPool,
        uint256 _contractBalance
    ) {
        return (totalCourses, totalStudents, rewardPool, address(this).balance);
    }
}
