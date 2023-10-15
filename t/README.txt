Test Case Layout and Environment Documentation

The test cases for the Bagger tools will follow a layout that follows the
following principles:

 1.  We aim at comprehensive testing for documented behavior though this is
 will take some time to build due to necessary prerequisites.

 2.  Not all test cases will be run by default.  In particular those which
 require a database connection or other special requirements will be optional.

 3.  The test layout will follow a clear path with more fundamental tests
 appearing earlier in the run, and integration tests at the end.

Test Case Layout:

The following conventions will be followed for test cases:

 0X - Basic, universal tests.  Things like whether Perl modules load, POD is
 wellformed, etc.

 1X - Testing for non-database-related modules and functionality. These are
 for utility functions only.

 2X - Testing for database-related modules, but non-database-related
 functionality.  These are still run by default.

 3X - Database creation and procedure tests.  These will only be run when
 appropriate environment variables are set, as are 4X-6X Tests

 4X - Database-related testing for database-related modules.

 5X - Integration tests

 6X - End to End Tooling Tests


Environment Variables for Non-Standard Tests:

The following variables are used to run database Tests:

   BAGGER_TEST_LW      -- If set, test the Lenkwerk Databases
   BAGGER_TEST_STORE   -- if set, test the storage databases
   BAGGER_TEST_LW_USER -- Username to log into create/use Lenkwerk db
   BAGGER_TEST_LW_HOST -- Host for the Lenkwerk DB
   BAGGER_TEST_LW_PORT -- Port for lenkwerk
   BAGGER_TEST_LW_DB   -- Database name for Lenkwerk DB

More of these will be added as we get to end to end testing and testing of
storage nodes.
