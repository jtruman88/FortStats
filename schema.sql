CREATE TABLE players (
  id serial PRIMARY KEY,
  username text NOT NULL UNIQUE,
  pass text NOT NULL,
  question text NOT NULL,
  admin boolean NOT NULL DEFAULT false
);

CREATE TABLE match_types (
  id serial PRIMARY KEY,
  match_type text NOT NULL
);

CREATE TABLE seasons (
  id serial PRIMARY KEY,
  season int NOT NULL,
  active boolean NOT NULL DEFAULT false
);

CREATE TABLE matches (
  id serial PRIMARY KEY,
  player_id int NOT NULL REFERENCES players (id),
  match_type_id int NOT NULL REFERENCES match_types (id),
  season_id int NOT NULL REFERENCES seasons (id),
  place_points int NOT NULL,
  elim_points int NOT NULL,
  place int NOT NULL,
  elims int DEFAULT 0,
  date_played timestamp DEFAULT NOW()
);

CREATE TABLE elim_points (
  id serial PRIMARY KEY,
  point_value int NOT NULL
);

CREATE TABLE place_points (
  id serial PRIMARY KEY,
  place int4range NOT NULL,
  point_value int NOT NULL
);

INSERT INTO place_points (place, point_value) VALUES
('[1,1]', 100), ('[2,2]', 94), ('[3,3]', 91),
('[4,4]', 88), ('[5,5]', 85), ('[6,6]', 80),
('[7,7]', 75), ('[8,8]', 70), ('[9,9]', 65),
('[10,10]', 60), ('[11,15]', 55), ('[16,20]', 50),
('[21,30]', 45), ('[31,40]', 40), ('[41,50]', 35), 
('[51,75]', 30), ('[76,100]', 25);

INSERT INTO elim_points (point_value) VALUES (10);

INSERT INTO match_types (match_type) VALUES
('solo'), ('duo'), ('squad');

INSERT INTO seasons (season) VALUES (6);

INSERT INTO players (username, pass, question, admin) VALUES
('JoLTsolo', '$2a$10$0y2uSTy2K/cquz5v2s.OxeRMJKljiNSmKaJS0oRY6adFYeupwJuo2',
       '$2a$10$QkF3brZa9M3vmSc28RMXJe0Kyof0LoWM9Ldnsg2ng4tgdoccQaJHq', true),
('Tester', '$2a$10$i1gffSAHEgbvkKB6PKt2FeKv/78aKfEAZl1mb0a2j6JWl6sDVnFi.',
       '$2a$10$/Be23DHWdQD7UNltncryT.9ZrAthy0bHiWlN4Svc8l3nsBH4LFeay', false);
       
INSERT INTO matches (player_id, match_type_id, season_id, place_points, elim_points, place, elims) VALUES
(1, 1, 1, 94, 20, 2, 2), (2, 1, 1, 94, 20, 2, 2), (1, 3, 1, 25, 60, 1, 3),
(2, 3, 1, 25, 60, 1, 3), (1, 1, 1, 55, 30, 12, 3), (2, 1, 1, 55, 30, 12, 3),
(1, 1, 1, 1, 60, 3, 6), (2, 1, 1, 1, 60, 3, 6), (1, 3, 1, 24, 100, 2, 5),
(2, 3, 1, 24, 100, 2, 5), (1, 3, 1, 22, 100, 4, 5), (2, 3, 1, 22, 100, 4, 5);