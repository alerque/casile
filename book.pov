#default {
	finish {
		ambient 0
		emission 0
	}
}

global_settings {
	// ambient_light 1
	radiosity {
		pretrace_start 0.08
		pretrace_end   0.01
		count 150
		nearest_count 10
		error_bound 0.5
		recursion_limit 1
		low_error_factor 0.5
		gray_threshold 0.0
		minimum_reuse 0.005
		maximum_reuse 0.2
		brightness 1
		adc_bailout 1/10
	}
	max_trace_level 10
	adc_bailout 1/20
}

#declare CoverThickness = 0.004;
#declare PaperInset = 0.0001;
#declare BX = 1 * BookAspect;
#declare BY = 1;
#declare StapleMM = 13;

#declare PaperPigment = pigment {
	gradient <0,1,0>
	color_map {
		[0.0 color rgb<0.59,0.57,0.55>]
		[0.5 color rgb<0.59,0.57,0.55>]
		[0.5 color rgb<0.79,0.76,0.73>]
		[0.5 color rgb<0.79,0.76,0.73>]
	}
	scale <0.003,0.003,0.003>
	rotate <90,0,0>
}

#declare BookFinish = finish {
	ambient 0.75
	emission 0.75
	diffuse 0.25
	reflection 0.01
	specular 0.25
	roughness 0.05
}

background { color SceneLight }

camera {
	location <(BX+BY/2)*-1,(BX/2+BY)*1.25,(BX+BY)*ViewZ>
	up y
	right x*6/8
	angle 35
	look_at <BX*0.4,0.50,HalfThick>
}

plane {
	y, 0
	pigment {
		color SceneLight
	}
	finish {
		ambient 0.2
		emission 0.2
	}
}

sky_sphere {
	pigment {
		color SceneLight
	}
	emission 1
}

light_source {
	<-0.2,8,3.0*ViewZ>
	color rgb<1, 1, 1>
	// spotlight
	// radius 10
	// falloff 14
	// point_at <BX/4,0,0>
	area_light <0.4, 0, 0>, <0, 0, 0.4>, Lights, Lights
	circular
}

light_source {
	<-8,3,-HalfThick>
	color rgb<0.5,0.5,0.5>
	// spotlight
	// radius 6
	// falloff 8
	// point_at <0,BX/2,0>
}

#macro Book (ThisBook)

	#include ThisBook

	#declare BZ = BookThickness;

	#if (strcmp(BindingType, "print")=0)
		#declare CoverThickness = PaperWeight / 866 * toMM;
	#else
		#declare CoverThickness = 0.004;
	#end

	// front cover
	box { <0,0,0> <1,1,CoverThickness>
		pigment {
			image_map {
				png FrontImg
				map_type 0
				interpolate 2
			}
		}
		scale <BookAspect,1,1>
		finish { BookFinish }
	}

	// back cover
	box {
		<0,0,0> <1,1,CoverThickness>
		pigment {
			image_map {
				png BackImg
				map_type 0
				interpolate 2
			}
			rotate <0,180,0>
		}
		scale <BookAspect,1,1>
		finish { BookFinish }
		translate <0,0,BZ-CoverThickness>
	}

	// spine
	#if (strcmp(BindingType, "print")!=0 & strcmp(BindingType, "coil")!=0 )
		difference {
			cylinder { <0,0,0>,<0,1,0>,(BZ/2)
				pigment {
					image_map {
						png SpineImg
						map_type 2
						interpolate 2
					}
				}
				#if (strcmp(BindingType, "paperback")=0)
					scale <0.1,1,1>
				#end
				#if (strcmp(BindingType, "stapled")=0)
					scale <2,1,1>
				#end
				translate <0,0,(BZ/2)>
				finish { BookFinish }
			}
			box {
				<0,-0.001,0> <1,1.001,BZ>
			}
		}
	#end

	#macro Staple ()
		box {
			<-BZ/2-(0.5*toMM),0,BZ/2-(0.25*toMM)>
			<0,StapleMM*toMM,BZ/2+(0.25*toMM)>
			pigment {
				color rgb<0.88,0.87,0.86>
			}
		}
	#end

	#macro Coil ()
		difference {
			cylinder {
				<0,0,BZ/2>
				<0,CoilWidth*toMM,BZ/2>
				BZ/2+5*toMM
				pigment {
					color CoilColor
				}
			}
			cylinder {
				<0,-0.0001,BZ/2>
				<0,CoilWidth*toMM+0.0001,BZ/2>
				BZ/2+4*toMM
				pigment {
					color CoilColor
				}
			}
		}
	#end

	#if (strcmp(BindingType, "stapled")=0)
		#declare StapleSpacing = 1 / StapleCount;
		#for (i, 1, StapleCount)
			union {
				Staple()
				translate <0,StapleSpacing/2 - StapleMM*toMM/2,0>
				translate <0,StapleSpacing*(i-1),0>
			}
		#end
	#end

	#if (strcmp(BindingType, "coil")=0)
		#declare CoilCount = int(1 / (CoilSpacing*toMM + CoilWidth*toMM));
		// #error concat("FROG FACE: ", str(CoilCount,5,0))
		#for (i, 1, CoilCount)
			union {
				Coil()
				translate <0,(1 - CoilWidth*CoilCount*toMM - CoilSpacing*CoilCount*toMM),0>
				translate <0,CoilWidth*toMM*(i-1),0>
				translate <0,CoilSpacing*toMM*(i-1),0>
			}
		#end
	#end

	// dimensions of pages
	#declare Paper = object {
		box {
			<0,0,0> <1,1,BZ-(CoverThickness*2)>
			scale <BookAspect,1,1>
			translate <0,0,CoverThickness>
		}
	}

	// pages box with inset
	box { min_extent(Paper) max_extent(Paper)-((PaperInset*2)*y)-(PaperInset*x)
		translate <0,PaperInset,0>
		pigment { PaperPigment }
		finish {
			ambient 0.4
			emission 0.4
		}
	}

#end

#macro BookFlip (ThisBook)

	union {
		Book(ThisBook)
		rotate <0,180,0>
		translate <BX,0,BZ>
	}

#end

Scene()
