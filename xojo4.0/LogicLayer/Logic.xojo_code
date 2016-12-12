#tag Module
Protected Module Logic
	#tag Method, Flags = &h1
		Protected Function ConnectRegDB(grab_saved_data as boolean = true) As Boolean
		  dim user_data() as Variant
		  dim dont_have_ud as Boolean
		  dim username as string
		  dim password as string
		  dim auto_login as Boolean
		  dim open_login_window as Boolean
		  dim save_username_checkbox as Boolean
		  dim save_password_checkbox as Boolean
		  dim auto_login_checkbox as Boolean
		  dim abort_login_loop as Boolean
		  dim remote_connected as Boolean
		  
		  
		  If grab_saved_data Then
		    // First we need to see if we can aquire a saved user name as password
		    Try
		      user_data = get_user_data
		    Catch err as RuntimeException
		      dont_have_ud = True
		      ErrManage( "App.RegDb", "could not get user credentials" )
		    End Try
		  Else
		    dont_have_ud = True
		  End If
		  
		  
		  // put user data into variables if they exist and determine if we should open the login window
		  If Not dont_have_ud Then 'we have the ud
		    username = user_data(0)
		    password = user_data(1)
		    auto_login = user_data(2)
		    If Not auto_login Then
		      open_login_window = True
		    End If
		  Else 'we donot hav ethe ud
		    open_login_window = True
		  End If
		  
		  // Getting user credentials from user
		  If open_login_window Then
		    'open a login windows to grab user info
		    dim dialog_box as new window_login
		    dialog_box.username = username
		    dialog_box.password = password
		    dialog_box.ShowModal
		    
		    'check if the user aborted the login
		    If dialog_box.aborted Then
		      'user aborted the login
		      remote_connected = False
		      Return False
		    Else 'user did not abort
		      'after user has closed the window we put all the info into some variables
		      username = dialog_box.username
		      password = dialog_box.password
		      save_username_checkbox = dialog_box.save_username
		      save_password_checkbox = dialog_box.save_password
		      auto_login_checkbox = dialog_box.auto_login
		    End If
		  End If
		  
		  
		  
		  'try to connect to the database
		  While Not abort_login_loop
		    
		    'set the database details
		    App.RegDb = new otis_PostgreSQL_Database
		    App.RegDb.UserName = username
		    App.RegDb.Password = password
		    App.RegDb.Host = "45.63.78.70"
		    App.RegDb.Port = 5432
		    App.RegDb.DatabaseName = "otis_client_reg"
		    
		    If Not App.RegDb.Connect Then
		      dim the_message as string = App.RegDb.ErrorMessage
		      ' check why the server connection failed
		      If Instr( the_message, "database" ) > 0 and InStr( the_message, "does not exist" ) > 0 Then
		        ' 1 | FATAL: database "db name" does not exist
		        dim err as new RuntimeException
		        err.Message = "Database " + App.RegDb.DatabaseName + " does not exist"
		        err.ErrorNumber = 010001
		        abort_login_loop = True
		        remote_connected = False
		        Raise err
		        
		      ElseIf InStr( the_message, "could not connect to server: Network is unreachable" ) > 0 Then
		        ' 1 | could not connect to server: Network is unreachable
		        dim err as new RuntimeException
		        err.Message = "Could not connect to server: Network is Unreachable"
		        err.ErrorNumber = 010003
		        abort_login_loop = True
		        remote_connected = False
		        Raise err
		        
		      ElseIf InStr( the_message, "password authentication failed" ) > 0 Then
		        ' 1 | FATAL: password authentication failed for user "..."
		        dim dialog as new window_login
		        dialog.authentication_failed = True
		        dialog.username = username
		        dialog.password = password
		        dialog.ShowModal
		        
		        'check if the user aborted the login
		        If dialog.aborted Then
		          'user aborted the login
		          remote_connected = False
		          Return False
		        Else 'user did not abort
		          'after user has closed the window we put all the info into some variables
		          username = dialog.username
		          password = dialog.password
		          save_username_checkbox = dialog.save_username
		          save_password_checkbox = dialog.save_password
		          auto_login_checkbox = dialog.auto_login
		        End If
		        
		      Else
		        remote_connected = False
		        dim err as RuntimeException
		        err.Message = App.RegDb.ErrorMessage
		        abort_login_loop = True
		        Raise err
		        
		      End If
		    Else
		      remote_connected = True
		      abort_login_loop = True
		      MsgBox( "connected" )
		    End If
		    
		    
		    
		    
		    
		  Wend
		  
		  'check if we need to save any user creds
		  redim user_data(-1)
		  If remote_connected Then
		    If save_username_checkbox Then
		      ReDim user_data(2)
		      user_data(0) = App.RegDb.UserName
		      
		      If save_password_checkbox Then
		        user_data(1) = App.RegDb.Password
		        
		        If auto_login_checkbox Then
		          user_data(2) = True
		        End If
		        
		      End If
		      
		      if save_user_data( user_data(0), user_data(1), user_data(2) ) then
		        MsgBox("saved")
		      end if
		    End If
		    
		    Return True
		    
		  Else 
		    
		    Return False
		    
		  End If
		  
		  
		  
		  
		  
		  
		  
		  
		  
		  
		  
		  
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub ErrManage(Facility as string, Message as string)
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Sub GetClientID()
		  Dim rs1 as RecordSet
		  
		  
		  
		  // Get a client ID
		  If Logic.ConnectRegDB Then
		    
		    rs1 = app.RegDB.SQLSelect("Select * From fnc_get_new_client_id();")
		    If app.RegDB.Error Then
		      dim err as RuntimeException
		      err.Message = app.RegDB.ErrorMessage
		    End If
		    
		    
		    If rs1 <> Nil Then
		      app.ClientID = rs1.Field("fnc_get_new_client_id").Value
		      SaveClientID
		    End If
		    
		    app.RegDB.Close
		    
		  End If
		  
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Function get_user_data() As variant()
		  dim udf as FolderItem
		  dim db as new SQLiteDatabase
		  dim ps as SQLitePreparedStatement
		  dim rs as RecordSet
		  Dim rd1 as New Logic.ResourceDirectories
		  
		  
		  
		  // find the filepath to our user data database
		  udf = rd1.user_data_file.FilePath
		  ' if the database already exists 
		  If Not udf.Exists Then
		    Return Array( "", "", False )
		  End If
		  
		  'Now we connect to the database file
		  db.DatabaseFile = udf
		  If Not db.Connect Then
		    ' cannot open the database file for some reaseon 
		    dim err as RuntimeException
		    err = new RuntimeException
		    err.Message = "cannot connect to user info database for some reason"
		    Raise err
		  End If
		  
		  ' now we grab the user data fromt he database
		  dim sql as string
		  sql = "Select * from udf_;"
		  ps = db.Prepare(sql)
		  rs = ps.SQLSelect
		  If db.Error Then
		    dim err as new RuntimeException
		    err.Message = "cannot get user data for some reaseon" + db.ErrorMessage
		    Raise err
		  End If
		  
		  If rs.RecordCount = 0 Then
		    dim err as new RuntimeException
		    err.Message = "cannot get user data for some reaseon" + db.ErrorMessage
		    Raise err
		  Else
		    dim username as string
		    dim password as string
		    dim auto_login as Boolean
		    username = rs.Field( "username_" )
		    password = rs.Field( "password_" )
		    auto_login = rs.Field( "auto_login" )
		    Return Array( username, password, auto_login )
		  End If
		  
		  
		  
		  
		  
		  
		  
		  
		  
		  
		  
		  
		  
		  
		  
		  
		  
		  
		  
		  
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Function HaveClientID() As Boolean
		  
		  If LoadClientID Then
		    
		    If app.ClientID = 0 Then
		      Return False
		    Else
		      Return True
		    End If
		    
		  Else 
		    
		    Return False
		    
		  End If
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Sub InitializeClient()
		  Dim RD1 as New Logic.ResourceDirectories
		  
		  
		  
		  
		  OtisDBModule.ResetDatabase
		  
		  // Create the database and tables
		  OtisDBModule.CreateDatabase
		  If Not OtisDBModule.CheckDatabase Then
		    'Database creation did not work
		    dim err as New RuntimeException
		    err.Message = "Something wrong with database creation"
		    ErrManage( "InitializeClient",err.Message + " | " + Join(err.Stack,",") )
		    raise err
		  End If
		  
		  // Create the Utility database
		  OtisDBModule.CreateDatabase(RD1.utility_db_file.FilePath,OtisDBModule.UtilityDatabaseCreationScript)
		  If Not OtisDBModule.CheckDatabase(rd1.utility_db_file.FilePath,OtisDBModule.UtilityDatabaseCheckScript) Then
		    'Database creation did not work
		    dim err as New RuntimeException
		    err.Message = "Something wrong with utility database creation"
		    ErrManage( "InitializeClient",err.Message + " | " + Join(err.Stack,",") )
		    raise err
		  End If
		  
		  
		  
		  // Install SymmetricDS 
		  // Initiate First sync
		  
		  
		  // Write to Initialized file
		  Dim f As FolderItem = RD1.initialized_file.FilePath
		  If f <> Nil Then
		    Try
		      //TextOutputStream.Create raises an IOException if it can't open the file for some reason.
		      Dim t As TextOutputStream = TextOutputStream.Create(f)
		      t.Write("True")
		      t = Nil
		    Catch e As IOException
		      //handle
		    End Try
		  End If
		  
		  
		  
		  
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Function IsInitialized() As Boolean
		  Dim RD1 as New Logic.ResourceDirectories
		  Dim TextValue as string
		  
		  
		  
		  Dim f As FolderItem = RD1.initialized_file.FilePath
		  If f <> Nil Then
		    If f.Exists Then
		      // Be aware that TextInputStream.Open coud raise an exception
		      Dim t As TextInputStream
		      Try
		        t = TextInputStream.Open(f)
		        TextValue = t.ReadAll
		        t.Close
		      Catch e As IOException
		        MsgBox("Error accessing initialized file.")
		      End Try
		    End If
		  End If
		  
		  
		  If TextValue <> "True" Then
		    ' Initialized file does not say we are initialized, so we know for sure we are not ready
		    Return False
		  Else
		    ' Initialized file says we are initialized, but we can't entirely trust
		    ' First we check if all of the tables are actually created correctly in the database
		    Dim bool1,bool2 as Boolean
		    bool1 = OtisDBModule.CheckDatabase
		    bool2 = OtisDBModule.CheckDatabase(rd1.utility_db_file.FilePath,OtisDBModule.UtilityDatabaseCheckScript)
		    rd1 = nil
		    If bool1 And bool2 Then
		      ' All tables are created correctly we can be pretty sure that we are ready to go
		      Return True
		    Else
		      ' Tables have not been created correctly, we must do a reset
		      Return False
		    End If
		  End If
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Function LoadClientID() As Boolean
		  Dim rd1 as New Logic.ResourceDirectories
		  
		  
		  Dim f As FolderItem = rd1.client_id_file.FilePath
		  If f <> Nil Then
		    If f.Exists Then
		      // Be aware that TextInputStream.Open coud raise an exception
		      Dim t As TextInputStream
		      Try
		        t = TextInputStream.Open(f)
		        app.ClientID = val( t.ReadAll )
		        t.Close
		      Catch e As IOException
		        Return False
		      End Try
		      
		      Return True
		      
		    End If
		    
		  Else
		    Return False
		    
		  End If
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Sub SaveClientID()
		  Dim rd1 As New Logic.ResourceDirectories
		  
		  
		  
		  Dim f As FolderItem = rd1.client_id_file.FilePath
		  If f <> Nil Then
		    Try
		      //TextOutputStream.Create raises an IOException if it can't open the file for some reason.
		      Dim t As TextOutputStream = TextOutputStream.Create(f)
		      t.Write(App.ClientID.ToText)
		      t = Nil
		    Catch e As IOException
		      //handle
		    End Try
		  End If
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h1
		Protected Function save_user_data(username as string, password as string, auto_login as boolean) As boolean
		  dim udf as FolderItem
		  dim db as new SQLiteDatabase
		  dim ps as SQLitePreparedStatement
		  dim rd1 as New Logic.ResourceDirectories
		  
		  
		  
		  // find the filepath to our user data database
		  udf = rd1.user_data_file.FilePath
		  ' if the database already exists 
		  If udf.Exists Then
		    udf.Delete
		  End If
		  
		  'Now we create a database file
		  db.DatabaseFile = udf
		  If Not db.CreateDatabaseFile Then
		    ' cannot open the database file for some reaseon 
		    dim err as RuntimeException
		    err = new RuntimeException
		    err.Message = "cannot connect to user info database for some reason"
		    Raise err
		  End If
		  
		  'Now we create the table and columns
		  dim sql as string
		  sql = "Create Table udf_ (username_ text, password_ text, auto_login Boolean );"
		  db.SQLExecute(sql)
		  If db.Error Then
		    dim err as RuntimeException
		    err = new RuntimeException
		    err.Message = "could not create user data table" + db.ErrorMessage
		    Raise err
		  End If
		  
		  'Finally we add the data to the table
		  sql = "Insert into udf_ ( username_, password_, auto_login ) Values( '" + username + "', '" + password + "', '" + str(auto_login) + "' );"
		  'ps = db.Prepare( sql )
		  'ps.Bind( 0, username )
		  'ps.Bind( 1, password )
		  'ps.Bind( 2, auto_login )
		  'ps.SQLExecute
		  db.SQLExecute(sql)
		  If db.Error Then
		    dim err as new RuntimeException
		    err.Message = "could not instert user data" + db.ErrorMessage
		    Raise err
		  End If
		  
		  Return True
		  
		  
		  
		  Exception err as runtimeException
		    Return False
		    
		    
		    
		    
		    
		    
		    
		    
		    
		    
		    
		    
		    
		    
		    
		    
		    
		    
		    
		    
		End Function
	#tag EndMethod


	#tag ViewBehavior
		#tag ViewProperty
			Name="Index"
			Visible=true
			Group="ID"
			InitialValue="-2147483648"
			Type="Integer"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Left"
			Visible=true
			Group="Position"
			InitialValue="0"
			Type="Integer"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Name"
			Visible=true
			Group="ID"
			Type="String"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Super"
			Visible=true
			Group="ID"
			Type="String"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Top"
			Visible=true
			Group="Position"
			InitialValue="0"
			Type="Integer"
		#tag EndViewProperty
	#tag EndViewBehavior
End Module
#tag EndModule