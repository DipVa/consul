require "csv"

class CensusApi

  def call( document_type, document_number, postal_code)
    puts "[DEBUG] Called the custom CensusApi class"

    response = nil

		nonce = 18.times.map{rand(10)}.join
		response = Response.new( get_response_body( document_type, document_number, nonce, postal_code ), nonce )

		# Si recibimos isHabitante = 0 comprobamos los Ayuntamientos que tienen cp en común.
		# En el caso de Tudela, comprobamos también la otra entidad correspondiente a Herrera
		if response!=nil && response.is_habitante == '0'
			nonce = 18.times.map{rand(10)}.join
			response = nil
			response = Response.new( get_response_body1( document_type, document_number, nonce, postal_code ), nonce )
		end


		return response
	end

	class Response

		def initialize( body, nonce )

			@data = Nokogiri::XML (Nokogiri::XML(body).at_css("servicioReturn"))
			@nonce = nonce

		end

		def valid?
			recibimosValid = ''+@data

			if recibimosValid.include? "recibido SML"
				edad = 0
			elsif recibimosValid.include? "Es repetido"
				edad = 0
			elsif recibimosValid.include? 'integridad'
				edad = 0
			elsif recibimosValid.include? "La Organiza"
				edad = 0
			else
				fechaActual = Time.now.strftime("%Y%m%d%H%M%S")
				fechaActualNumeric = BigDecimal.new(fechaActual);
				fechaNacimientoNumeric = BigDecimal.new(date_of_birth);
				edad = fechaActualNumeric-fechaNacimientoNumeric
			end


			return (exito == "-1") && (response_nonce==@nonce) && (is_habitante == "-1") && (edad >= 160000000000)

		end

		def exito
			@data.at_css("exito").content
		end

		def response_nonce
			@data.at_css("nonce").content
		end

#		def postal_code
#			Base64.decode64 (@data.at_css("codigoPostal").content)
#		end

		def is_habitante
			recibimosHabitante = ''+@data
			if recibimosHabitante.include? 'recibido SML'
				# no hacemos nada. El usuario no corresponde a ningún padrón de la diputación
				puts "No es usuario- SML"
			elsif recibimosHabitante.include? 'Es repetido'
				puts "No es usuario - repetido"
			elsif recibimosHabitante.include? 'integridad'
				puts "No es usuario- integridad"
			elsif recibimosHabitante.include? 'La Organiza'
				puts "No es usuario- La organización no existe"
			else
				@data.at_css("isHabitante").content
			end
		end

		def date_of_birth
			recibimos = ''+@data

			if recibimos.include? 'recibido SML'
				# no hacemos nada. El usuario no corresponde a ningún padrón de la diputación
				puts "No es usuario-SML"
			elsif recibimos.include? 'Es repetido'
				puts "No es usuario-REPETIDO"
			elsif recibimos.include? 'integridad'
				puts "No es usuario-integridad"
			elsif recibimos.include? "La Organiza"
				edad = 0
			else
				@data.at_css("fechaNacimiento").content
			end
		end

		def document_number
			Base64.decode64 (@data.at_css("documento").content)
		end
	end

	private


	def codificar( origen )
		Digest::SHA512.base64digest( origen )
	end

	def cod64 (entrada)
		Base64.encode64( entrada ).delete("\n")
	end

	def codpass (origen)
		Digest::SHA1.base64digest( origen )
	end

	# Tudela de Duero
	def get_response_body( document_type, document_number, nonce, postal_code )

		fecha = Time.now.strftime("%Y%m%d%H%M%S")

		origen = nonce + fecha + Rails.application.secrets.padron_public_key
		token = codificar( origen )
		user = Rails.application.secrets.padron_user
		pwd = codpass( Rails.application.secrets.padron_password )

			peticion= "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
			peticion += "<SOAP-ENV:Envelope xmlns:SOAP-ENV=\"http://schemas.xmlsoap.org/soap/envelope/\" SOAP-ENV:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\">"
			peticion += "<SOAP-ENV:Body>"
			peticion += "<m:servicio xmlns:m=\""+Rails.application.secrets.padron_host+"\">"
			peticion += "<sml>"
			peticion += Rack::Utils.escape_html("<E>\n\t<OPE>\n\t\t<APL>PAD</APL>\n\t\t<TOBJ>HAB</TOBJ>\n\t\t<CMD>ISHABITANTE</CMD>\n\t\t<VER>2.0</VER>\n\t</OPE>\n\t<SEC>\n\t\t<CLI>ACCEDE</CLI>\n\t\t<ORG>175</ORG>\n\t\t<ENT>175</ENT>\n\t\t<USU>"+user+"</USU>\n\t\t<PWD>"+pwd+"</PWD>\n\t\t<FECHA>"+fecha+"</FECHA>\n\t\t<NONCE>"+nonce+"</NONCE>\n\t\t<TOKEN>"+token+"</TOKEN>\n\t</SEC>\n\t<PAR>\n\t\t<nia></nia>\n\t\t<codigoTipoDocumento>1</codigoTipoDocumento>\n\t\t<documento>" + cod64(document_number) + "</documento>\n\t\t<mostrarFechaNac>-1</mostrarFechaNac>\n\t</PAR>\n</E>")
			peticion += "</sml>"
			peticion += "</m:servicio>"
			peticion += "</SOAP-ENV:Body></SOAP-ENV:Envelope>"

			puts "peticion Tudela: "+peticion
			respuesta = RestClient.post( Rails.application.secrets.padron_host, peticion,  {:content_type => "text/xml; charset=utf-8", :SOAPAction => Rails.application.secrets.padron_host } )

			puts "respuestaWS Tudela: "+respuesta

		respuesta
	end

	# Herrera de Duero
	def get_response_body1( document_type, document_number, nonce, postal_code )

		fecha = Time.now.strftime("%Y%m%d%H%M%S")

		origen = nonce + fecha + Rails.application.secrets.padron_public_key
		token = codificar( origen )
		user = Rails.application.secrets.padron_user
		pwd = codpass( Rails.application.secrets.padron_password )

			peticion= "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
			peticion += "<SOAP-ENV:Envelope xmlns:SOAP-ENV=\"http://schemas.xmlsoap.org/soap/envelope/\" SOAP-ENV:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\">"
			peticion += "<SOAP-ENV:Body>"
			peticion += "<m:servicio xmlns:m=\""+Rails.application.secrets.padron_host+"\">"
			peticion += "<sml>"
			peticion += Rack::Utils.escape_html("<E>\n\t<OPE>\n\t\t<APL>PAD</APL>\n\t\t<TOBJ>HAB</TOBJ>\n\t\t<CMD>ISHABITANTE</CMD>\n\t\t<VER>2.0</VER>\n\t</OPE>\n\t<SEC>\n\t\t<CLI>ACCEDE</CLI>\n\t\t<ORG>93</ORG>\n\t\t<ENT>93</ENT>\n\t\t<USU>"+user+"</USU>\n\t\t<PWD>"+pwd+"</PWD>\n\t\t<FECHA>"+fecha+"</FECHA>\n\t\t<NONCE>"+nonce+"</NONCE>\n\t\t<TOKEN>"+token+"</TOKEN>\n\t</SEC>\n\t<PAR>\n\t\t<nia></nia>\n\t\t<codigoTipoDocumento>1</codigoTipoDocumento>\n\t\t<documento>" + cod64(document_number) + "</documento>\n\t\t<mostrarFechaNac>-1</mostrarFechaNac>\n\t</PAR>\n</E>")
			peticion += "</sml>"
			peticion += "</m:servicio>"
			peticion += "</SOAP-ENV:Body></SOAP-ENV:Envelope>"

			puts "peticion Herrera: "+peticion
			respuesta = RestClient.post( Rails.application.secrets.padron_host, peticion,  {:content_type => "text/xml; charset=utf-8", :SOAPAction => Rails.application.secrets.padron_host } )

			puts "respuestaWS Herrera: "+respuesta

		respuesta
	end
end
