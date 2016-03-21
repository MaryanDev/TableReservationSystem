USE TRS_DB

GO

CREATE PROC sp_GetUserByLogin
	@login VARCHAR(50),
	@passwordHash VARCHAR(50)
AS
BEGIN
	SELECT 
		Id, 
		FirstName, 
		LastName, 
		[Login],		 
		[Disabled] 
	FROM tblUser
	WHERE [Login] = @login AND [PasswordHash] = @passwordHash AND [Disabled] <> 1;
END;

GO

CREATE PROC sp_GetReservationsByDate
	@reservationDate DATETIME
AS
BEGIN
	SELECT
		res.Id,
		tab.Id as TableId,
		tab.Rate,
		tab.CountOfSeats,
		loc.Id as LocationId,
		loc.Name as LocationName,
		cust.Id as CustomerId,
		cust.FirstName as FirstName,
		cust.LastName as LastName,
		cust.Phone as Phone,
		res.DateIn,
		res.DateOut,
		res.[Status],
		res.Cost,
		res.UserId
	FROM tblReservation res
	JOIN tblTable tab
	ON res.Id = tab.Id
	JOIN tblCustomer cust
	ON res.CustomerId = cust.Id
	JOIN tblLocation loc
	ON tab.LocationId = loc.Id
	WHERE (DATEDIFF(day, res.dateIn, @reservationDate) = 0) AND res.[Status] = 1;		
END;

GO

CREATE PROCEDURE sp_ReserveTable
	@firstName NVARCHAR(50),
	@lastName NVARCHAR(50),
	@phone VARCHAR(30),
	@dateIn DATETIME,
	@dateOut DATETIME,
	@tableId INT,
	@userId INT,
	@reservationId INT OUT
AS
BEGIN
	BEGIN TRAN
		DECLARE @customerId INT;
		SELECT @customerId = cust.Id FROM tblCustomer cust 
			WHERE (cust.Phone = @phone);

		IF (@customerId IS NULL)
		BEGIN
			INSERT INTO tblCustomer(FirstName, LastName, Phone) VALUES(@firstName, @lastName, @phone);
			SET @customerId = @@IDENTITY;
		END;

		IF (@dateIn > @dateOut)
		BEGIN
			ROLLBACK TRAN;
			THROW 60000 ,'Reservation start date and time must be greater than finish date and time!', 1;
		END;

		IF EXISTS(SELECT 1 FROM tblReservation res 
			WHERE (res.TableId = @tableId) AND (res.[Status] = 1) AND
					NOT ((@dateIn < res.DateIn AND @dateOut < res.DateIn) OR
						(@dateIn > res.DateOut AND @dateOut > res.DateOut)))
			BEGIN
				ROLLBACK TRAN;
				THROW 60000, 'This table is already rent for such date', 1;
			END
	
		DECLARE @cost NUMERIC(18, 4);
		DECLARE @rate NUMERIC(18, 4);
		DECLARE @minutes INT;

		SELECT @rate = tab.Rate FROM tblTable tab WHERE tab.Id = @tableId;
		SELECT @minutes = DATEDIFF(minute, @dateIn, @dateOut);
		SET @cost = (@rate / 30) * @minutes;

		INSERT INTO tblReservation (TableId, CustomerId, DateIn, DateOut, [Status], Cost, UserId)
		VALUES (@tableId, @customerId, @dateIn, @dateOut, 1, @cost, @userId);
	
		SET @reservationId = @@IDENTITY;
	COMMIT TRAN;
END;

GO

--DECLARE @result INT;

--DECLARE @returnValue INT;
--EXEC @returnValue = sp_ReserveTable 'Yura', 'Skolozdra', '099-777-33-11', '2016-03-25 20:00:00', '2016-03-25 21:00:00', 10, 1, @result out;
--PRINT CAST(@returnValue AS NVARCHAR);
--IF (@returnValue = NULL)
--begin
--	print 'return is null';
--end;

--GO

--delete from tblReservation where id = 12;


DECLARE @reservationTime DATETIME;
SET @reservationTime = '2016-03-25 15:00:00.000';

EXEC sp_GetReservationsByDate @reservationTime;
GO

