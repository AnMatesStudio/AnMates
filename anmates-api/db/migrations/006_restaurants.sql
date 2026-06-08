-- 006_restaurants.sql — venue catalog for the AI Concierge / map features.
-- Slice subset of meetup-map-master-plan §11: uses lat/lng + Haversine (no PostGIS yet).
-- Production rows are ingested from Goong (goong.io) — Google Maps Platform is prohibited in VN.
-- This migration seeds a curated set of real HCMC District 1/3 venues (source='seed')
-- so the concierge has real venues to recommend in dev/E2E.

CREATE TABLE restaurants (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name          text NOT NULL,
  address       text,
  district      text,
  lat           double precision NOT NULL,
  lng           double precision NOT NULL,
  cuisine_tags  text[] NOT NULL DEFAULT '{}',
  price_min     int,                       -- VND per person
  price_max     int,
  rating        double precision,          -- scans cleanly into Go *float64
  photos        text[] NOT NULL DEFAULT '{}',
  status        text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active','hidden','pending')),
  source        text NOT NULL DEFAULT 'seed'
    CHECK (source IN ('seed','goong','osm')),
  source_ref    text,
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- Discovery / candidate-search support. Bounding-box prefilter on lat/lng before Haversine.
CREATE INDEX idx_restaurants_latlng ON restaurants(lat, lng);
CREATE INDEX idx_restaurants_status ON restaurants(status);
CREATE INDEX idx_restaurants_cuisine ON restaurants USING gin(cuisine_tags);

-- Seed: real, well-known HCMC District 1/3 eateries (coords approximate, central HCMC).
-- price in VND per person. Replace/augment via Goong ingest later.
INSERT INTO restaurants (name, address, district, lat, lng, cuisine_tags, price_min, price_max, rating) VALUES
  ('Bún Bò Giáo Toàn',        '5 Lê Văn Sỹ, P.13',          'Q3', 10.7882, 106.6790, ARRAY['bun','bun_bo'],            50000, 90000, 4.6),
  ('Phở Hòa Pasteur',         '260C Pasteur, P.8',          'Q3', 10.7869, 106.6905, ARRAY['pho'],                     60000, 110000, 4.4),
  ('Cơm Tấm Ba Ghiền',        '84 Đặng Văn Ngữ, P.10',      'PN', 10.7930, 106.6772, ARRAY['com','com_tam'],           50000, 95000, 4.5),
  ('Bún Chả Hà Nội',          '26 Nguyễn Thị Diệu, P.6',    'Q3', 10.7799, 106.6925, ARRAY['bun','bun_cha'],           50000, 85000, 4.3),
  ('Lẩu Dê 555',              '79 Trương Định, P.6',        'Q3', 10.7771, 106.6907, ARRAY['lau','de'],                150000, 300000, 4.2),
  ('Pizza 4P''s Lê Thánh Tôn','8/15 Lê Thánh Tôn, P.Bến Nghé','Q1', 10.7790, 106.7035, ARRAY['pizza','italian'],      200000, 420000, 4.7),
  ('Gogi House Nguyễn Du',    '21 Nguyễn Du, P.Bến Nghé',   'Q1', 10.7785, 106.6948, ARRAY['bbq','korean','nuong'],   170000, 280000, 4.3),
  ('Bánh Mì Huỳnh Hoa',       '26 Lê Thị Riêng, P.Bến Thành','Q1', 10.7686, 106.6906, ARRAY['banh_mi'],                45000, 75000, 4.5),
  ('Ốc Đào',                  '212B Nguyễn Trãi, P.Nguyễn Cư Trinh','Q1', 10.7642, 106.6863, ARRAY['oc','seafood'],   80000, 160000, 4.4),
  ('Nhà Hàng Ngon 138',       '138 Nam Kỳ Khởi Nghĩa, P.Bến Nghé','Q1', 10.7820, 106.6957, ARRAY['vietnamese','com'], 100000, 220000, 4.3),
  ('Bún Đậu Mắm Tôm A Chảnh', '64 Trương Định, P.7',        'Q3', 10.7846, 106.6892, ARRAY['bun','bun_dau'],          60000, 110000, 4.2),
  ('Sushi Hokkaido Sachi',    '47 Lê Thánh Tôn, P.Bến Nghé','Q1', 10.7799, 106.7012, ARRAY['japanese','sushi'],       160000, 320000, 4.4),
  ('Cộng Cà Phê Đồng Khởi',   '26 Lý Tự Trọng, P.Bến Nghé', 'Q1', 10.7757, 106.7007, ARRAY['cafe','trang_mieng'],     45000, 90000, 4.3),
  ('Quán Bụi Saigon',         '17A Ngô Văn Năm, P.Bến Nghé','Q1', 10.7811, 106.7045, ARRAY['vietnamese','com'],       110000, 200000, 4.5),
  ('Phúc Long Coffee & Tea',  '76 Hai Bà Trưng, P.Bến Nghé','Q1', 10.7770, 106.7009, ARRAY['cafe','trang_mieng'],     40000, 85000, 4.1),
  ('Bánh Xèo 46A',            '46A Đinh Công Tráng, P.Tân Định','Q1', 10.7905, 106.6889, ARRAY['banh_xeo','vietnamese'],70000, 130000, 4.5),
  ('Highlands Coffee Bitexco','2 Hải Triều, P.Bến Nghé',    'Q1', 10.7715, 106.7043, ARRAY['cafe'],                   45000, 95000, 4.0),
  ('Lẩu Nấm Ashima',          '35 Lê Quý Đôn, P.7',         'Q3', 10.7836, 106.6889, ARRAY['lau','nam'],              200000, 380000, 4.4);
