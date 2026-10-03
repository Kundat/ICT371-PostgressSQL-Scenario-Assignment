DROP TABLE IF EXISTS reservations;
DROP TABLE IF EXISTS lab_sessions;
CREATE TABLE lab_sessions (
 session_id SERIAL PRIMARY KEY,
 session_name VARCHAR(60) NOT NULL,
 available_workstations INT NOT NULL CHECK (available_workstations >= 0)
);
CREATE TABLE reservations (
 reservation_id SERIAL PRIMARY KEY,
 session_id INT NOT NULL REFERENCES lab_sessions(session_id),
 lecturer VARCHAR(60) NOT NULL,
 num_workstations INT NOT NULL CHECK (num_workstations > 0),
 status VARCHAR(10) NOT NULL DEFAULT 'RESERVED'
 CHECK (status IN ('RESERVED', 'CANCELLED'))
);
INSERT INTO lab_sessions (session_name, available_workstations) VALUES
 ('Monday 08:00 Programming Lab', 30),
 ('Tuesday 10:00 Networking Lab', 4),
 ('Wednesday 14:00 Database Lab', 0);
 SELECT * FROM lab_sessions ORDER BY session_id;
 
 DO $$
DECLARE
 rec RECORD;
BEGIN
 FOR rec IN SELECT session_name, available_workstations
 FROM lab_sessions ORDER BY session_id LOOP
 IF rec.available_workstations = 0 THEN
 RAISE NOTICE '% : FULL', rec.session_name;
 ELSIF rec.available_workstations <= 5 THEN
 RAISE NOTICE '% : NEARLY FULL (% left)', rec.session_name, rec.available_workstations;
 ELSE
 RAISE NOTICE '% : enough workstations (%)', rec.session_name, rec.available_workstations;
 END IF;
 END LOOP;
END $$;

DO $$
DECLARE
 reminder_no INT := 1;
BEGIN
 WHILE reminder_no <= 3 LOOP
 RAISE NOTICE 'Session preparation reminder %', reminder_no;
 reminder_no := reminder_no + 1;
 END LOOP;
 FOR check_no IN 1..3 LOOP
 RAISE NOTICE 'Workstation check number %', check_no;
 END LOOP;
END $$;


CREATE OR REPLACE PROCEDURE reserve_workstations(
 p_session_id INT, p_lecturer VARCHAR, p_count INT)
LANGUAGE plpgsql
AS $$
DECLARE
 v_available INT;
BEGIN
 IF p_count IS NULL OR p_count <= 0 THEN
 RAISE EXCEPTION 'Invalid number of workstations: % (must be greater than zero)', p_count
 USING ERRCODE = '22023';
 END IF;
 SELECT available_workstations INTO v_available
 FROM lab_sessions WHERE session_id = p_session_id FOR UPDATE;
 IF NOT FOUND THEN
 RAISE EXCEPTION 'Session % does not exist', p_session_id;
 END IF;
 IF v_available < p_count THEN
 RAISE EXCEPTION 'Only % workstations available, % requested', v_available, p_count;
 END IF;
 UPDATE lab_sessions
 SET available_workstations = available_workstations - p_count
 WHERE session_id = p_session_id;
 INSERT INTO reservations (session_id, lecturer, num_workstations)
 VALUES (p_session_id, p_lecturer, p_count);
 RAISE NOTICE 'Reserved % workstation(s) in session % for %',
 p_count, p_session_id, p_lecturer;
END $$;

DO $$
BEGIN
 CALL reserve_workstations(1, 'Dr Banda', 20); -- valid
 CALL reserve_workstations(2, 'Mr Phiri', 3); -- valid
 BEGIN
 CALL reserve_workstations(2, 'Ms Zulu', 10); -- exceeds capacity
 EXCEPTION WHEN OTHERS THEN
 RAISE NOTICE 'Reservation rejected: %', SQLERRM;
 END;
END $$;
SELECT * FROM lab_sessions ORDER BY session_id;
SELECT * FROM reservations ORDER BY reservation_id;

CREATE OR REPLACE PROCEDURE cancel_reservation(p_reservation_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
 v_session_id INT;
 v_count INT;
BEGIN
 UPDATE reservations SET status = 'CANCELLED'
 WHERE reservation_id = p_reservation_id AND status = 'RESERVED'
 RETURNING session_id, num_workstations INTO v_session_id, v_count;
 IF NOT FOUND THEN
 RAISE NOTICE 'Reservation % is not active or does not exist - nothing released', p_reservation_id;
 ELSE
 UPDATE lab_sessions
 SET available_workstations = available_workstations + v_count
 WHERE session_id = v_session_id;
 RAISE NOTICE 'Reservation % cancelled - % workstation(s) released', p_reservation_id, v_count;
 END IF;
END $$;
CALL cancel_reservation(1); -- releases workstations
CALL cancel_reservation(1); -- second call: nothing released
SELECT * FROM lab_sessions ORDER BY session_id;
SELECT * FROM reservations ORDER BY reservation_id;

DO $$
DECLARE
 cur_few CURSOR FOR
 SELECT session_id, session_name, available_workstations
 FROM lab_sessions WHERE available_workstations <= 5
 ORDER BY available_workstations;
 rec RECORD;
BEGIN
 OPEN cur_few;
 LOOP
 FETCH cur_few INTO rec;
 EXIT WHEN NOT FOUND;
 RAISE NOTICE 'Few workstations left: % (id %) - %',
 rec.session_name, rec.session_id, rec.available_workstations;
 END LOOP;
 CLOSE cur_few;
END $$;

DO $$
BEGIN
 CALL reserve_workstations(1, 'Dr Banda', 0);
EXCEPTION
 WHEN invalid_parameter_value THEN
 RAISE NOTICE 'Handled invalid quantity: %', SQLERRM;
END $$;
SELECT session_id, session_name, available_workstations
FROM lab_sessions ORDER BY session_id;
SELECT reservation_id, session_id, lecturer, num_workstations, status
FROM reservations ORDER BY reservation_id;
