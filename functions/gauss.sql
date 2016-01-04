-----------------------------------------------------------------------------
-- Copyright (c) 2010-2015 Dmitry Vazhenin <DmitryZav@users.noreply.github.com>
-- https://github.com/DmitryZav/
--
-- This file is part of Constellation Kings game project.
--
-- This file is subject to the terms and conditions defined in
-- file 'LICENSE', which is part of this source code package. 
-----------------------------------------------------------------------------
-- Standard Gaussian distribution function
-- parameters:
-- mean - median offset
-- stdev - deviation (squared sigma)
-----------------------------------------------------------------------------

DELIMITER $$

CREATE FUNCTION `GAUSS`(mean float, stdev float) RETURNS float
BEGIN
 return ((sqrt(-2*log(rand()))*cos(2*pi()*rand()))*stdev)+mean;
END
