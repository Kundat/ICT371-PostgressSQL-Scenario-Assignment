DROP TABLE IF EXISTS allocations;
DROP TABLE IF EXISTS hostel_rooms;
CREATE TABLE hostel_rooms (
 room_id SERIAL PRIMARY KEY,
 room_name VARCHAR(20) NOT NULL,
 available_spaces INT NOT NULL CHECK (available_spaces >= 0)
);
CREATE TABLE allocations (
 allocation_id SERIAL PRIMARY KEY,
 student_number VARCHAR(20) NOT NULL,
 room_id INT NOT NULL REFERENCES hostel_rooms(room_id),
 status VARCHAR(10) NOT NULL DEFAULT 'ALLOCATED'
 CHECK (status IN ('ALLOCATED', 'COMPLETE'))
);
INSERT INTO hostel_rooms (room_name, available_spaces) VALUES
 ('Room A101', 4),
 ('Room B202', 1),
 ('Room C303', 0);
 
SELECT * FROM hostel_rooms ORDER BY room_id;

DO $$
DECLARE
 rec RECORD;
BEGIN
 FOR rec IN SELECT room_name, available_spaces FROM hostel_rooms ORDER BY room_id LOOP
 IF rec.available_spaces = 0 THEN
 RAISE NOTICE '% : FULL', rec.room_name;
 ELSIF rec.available_spaces = 1 THEN
 RAISE NOTICE '% : ONE space left', rec.room_name;
 ELSE
 RAISE NOTICE '% : several spaces (%)', rec.room_name, rec.available_spaces;
 END IF;
 END LOOP;
END $$;

DO $$
DECLARE
 day_no INT := 1;
BEGIN
 WHILE day_no <= 3 LOOP
 RAISE NOTICE 'Hostel inspection day %', day_no;
 day_no := day_no + 1;
 END LOOP;
 FOR check_no IN 1..3 LOOP
 RAISE NOTICE 'Room check number %', check_no;
 END LOOP;
END $$;

CREATE OR REPLACE PROCEDURE allocate_room(p_student_number VARCHAR, p_room_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
 v_spaces INT;
BEGIN
 IF p_student_number IS NULL OR btrim(p_student_number) = '' THEN
 RAISE EXCEPTION 'Student number cannot be blank'
 USING ERRCODE = '22023';
 END IF;
 SELECT available_spaces INTO v_spaces
 FROM hostel_rooms WHERE room_id = p_room_id FOR UPDATE;
 IF NOT FOUND THEN
 RAISE EXCEPTION 'Room % does not exist', p_room_id;
 END IF;
IF v_spaces < 1 THEN
 RAISE EXCEPTION 'Room % is full', p_room_id;
 END IF;
 UPDATE hostel_rooms SET available_spaces = available_spaces - 1
 WHERE room_id = p_room_id;
 INSERT INTO allocations (student_number, room_id)
 VALUES (p_student_number, p_room_id);
 RAISE NOTICE 'Student % allocated to room %', p_student_number, p_room_id;
END $$;

SELECT * FROM hostel_rooms ORDER BY room_id;
SELECT * FROM allocations ORDER BY allocation_id;


CREATE OR REPLACE PROCEDURE check_out(p_allocation_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
 v_room_id INT;
BEGIN
 UPDATE allocations SET status = 'COMPLETE'
 WHERE allocation_id = p_allocation_id AND status = 'ALLOCATED'
 RETURNING room_id INTO v_room_id;
 IF NOT FOUND THEN
 RAISE NOTICE 'Allocation % is not active or does not exist - no space freed', p_allocation_id;
 ELSE
 UPDATE hostel_rooms SET available_spaces = available_spaces + 1
 WHERE room_id = v_room_id;
 RAISE NOTICE 'Allocation % complete - one space freed in room %', p_allocation_id, v_room_id;
 END IF;
END $$;
CALL check_out(1); -- frees one space
CALL check_out(1); -- second call: nothing freed

SELECT * FROM hostel_rooms ORDER BY room_id;
SELECT * FROM allocations ORDER BY allocation_id;

DO $$
DECLARE
 cur_rooms CURSOR FOR
 SELECT room_id, room_name, available_spaces
FROM hostel_rooms WHERE available_spaces <= 1
 ORDER BY available_spaces, room_id;
 rec RECORD;
BEGIN
 OPEN cur_rooms;
 LOOP
 FETCH cur_rooms INTO rec;
 EXIT WHEN NOT FOUND;
 IF rec.available_spaces = 0 THEN
 RAISE NOTICE '% is FULL', rec.room_name;
 ELSE
 RAISE NOTICE '% is nearly full (% space left)', rec.room_name, rec.available_spaces;
 END IF;
 END LOOP;
 CLOSE cur_rooms;
END $$;

DO $$
BEGIN
 CALL allocate_room(' ', 1);
EXCEPTION
 WHEN invalid_parameter_value THEN
 RAISE NOTICE 'Handled invalid input: %', SQLERRM;
END $$;

SELECT room_id, room_name, available_spaces FROM hostel_rooms ORDER BY room_id;
SELECT allocation_id, student_number, room_id, status
FROM allocations ORDER BY allocation_id;



