package edu.nyu.xyz.parser;

import java.io.FileNotFoundException;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;

import org.json.simple.JSONArray;
import org.json.simple.JSONObject;
import org.json.simple.parser.JSONParser;
import org.json.simple.parser.ParseException;

import com.cedarsoftware.util.io.JsonWriter;

public class LinkedInDataParser {

	public static void main(String[] args) {
		String companyPositionSkillInputFilePath =  
				"/Users/longyang/git/RealTimeBigData/data/linkedin/LinkedInCleanData.json";
		String companyPositionSkillOutputFilePath =
				"/Users/longyang/git/RealTimeBigData/data/linkedin/CompanyPositionSkill.json";
		
//		companyPositionSkills(
//				"/Users/longyang/git/RealTimeBigData/data/linkedin/linkedin/9.json", 
//				"/Users/longyang/git/RealTimeBigData/data/linkedin/linkedin/out/9.json");
		companyPositionSkill(companyPositionSkillInputFilePath, 
				companyPositionSkillOutputFilePath);
	}
	
	/**
	 * Method used to get the company, position and skills of a LinkedIn member from his profile,
	 * and we will get rid of incomplete data, such as one of the three fields is empty.
	 * 
	 * @param inputFilePath path for the input file from local storage.
	 * @param outputFilePath path for output file and the output file is as the following format:
	 * {
	 * 	{@code ParserConstants#COMPANY} : "",
	 * 	{@code ParserConstants#POSITION} : "",
	 * 	{@code ParserConstants#SKILLS} : []
	 * }
	 * 
	 */
	@SuppressWarnings({ "unchecked"})
	public static void companyPositionSkills(String inputFilePath, String outputFilePath) {
		if (inputFilePath == null || inputFilePath.isEmpty() ||
				outputFilePath == null || outputFilePath.isEmpty()) {
			throw new IllegalArgumentException("The inputFile and outputFile path should "
					+ "not be null or empty!");
		}
		JSONParser parser = new JSONParser();
		
		try {
			FileReader inputFile = new FileReader(inputFilePath);
			Object object = parser.parse(inputFile);
			JSONArray inputJsonArray = new JSONArray();
			JSONArray outputJsonArray = new JSONArray();
			
			if (object instanceof JSONArray) {
				inputJsonArray = (JSONArray)object;
			} else {
				throw new Exception("Input LinkedIn data should be a Json Array!");
			}
			
			for (int i = 0; i < inputJsonArray.size(); i++) {
				System.out.println("Number: " + i);
				Object profile = inputJsonArray.get(i);
				JSONObject jsonProfile = new JSONObject();
				JSONObject outputJsonProfile = new JSONObject();
				
				if (profile instanceof JSONObject) {
					jsonProfile = (JSONObject)profile;
				} else {
					throw new Exception("Items inside LinkedIn Json Data should be JSONObject!");
				}
				JSONArray currentCompany = (JSONArray)jsonProfile.get(ParserConstants.CURRENT_COMPANY);
				JSONArray currentPosition = (JSONArray)jsonProfile.get(ParserConstants.CURRENT_POSITION);
				JSONArray skills = (JSONArray)jsonProfile.get(ParserConstants.SUMMARYSPECIALTIES);
				
				if (currentCompany != null && currentCompany.size() == 1 ) {
					outputJsonProfile.put(ParserConstants.COMPANY, (String)currentCompany.get(0));
				} else {
					continue;
				}
				if (currentPosition != null && currentPosition.size() == 1) {
					outputJsonProfile.put(ParserConstants.POSITION, (String)currentPosition.get(0));
				} else {
					continue;
				}
				if (skills != null && !skills.isEmpty()) {
					outputJsonProfile.put(ParserConstants.SKILLS, skills);
				} else {
					continue;
				}
				
				outputJsonArray.add(outputJsonProfile);
			}
			System.out.println("Done! And the size of final good LinkedIn profiles is: " + 
					outputJsonArray.size());
			
			String niceFormatJsonAllPositions = JsonWriter.formatJson(outputJsonArray.toJSONString());
			FileWriter outputFileWriter = new FileWriter(outputFilePath);
			outputFileWriter.write(niceFormatJsonAllPositions);
			outputFileWriter.flush();
			outputFileWriter.close();
			
		} catch (FileNotFoundException e) {
			e.printStackTrace();
		} catch (IOException e) {
			e.printStackTrace();
		} catch (ParseException e) {
			e.printStackTrace();
		} catch (Exception e) {
			e.printStackTrace();
		}
	}
	
	@SuppressWarnings("unchecked")
	public static void companyPositionSkill(String inputFilePath, String outputFilePath) {
		if (inputFilePath == null || inputFilePath.isEmpty() ||
				outputFilePath == null || outputFilePath.isEmpty()) {
			throw new IllegalArgumentException("Both inputFilePath and outputFilePath should not be "
					+ "null or empty!");
		}
		
		JSONParser parser = new JSONParser();
		
		try {
			FileReader reader = new FileReader(inputFilePath);
			Object object = parser.parse(reader);
			JSONArray inputJsonArray = (JSONArray) object;
			JSONArray outputJsonArray = new JSONArray();
			
			for (int i = 0; i < inputJsonArray.size(); i++) {
				JSONObject inputObject = (JSONObject) inputJsonArray.get(i);
				String companyName = (String) inputObject.get(ParserConstants.COMPANY);
				String position = (String) inputObject.get(ParserConstants.POSITION);
				JSONArray skills = (JSONArray) inputObject.get(ParserConstants.SKILLS);
				
				for (int j = 0; j < skills.size(); j++) {
					String skill = (String) skills.get(j);
					JSONObject outputObject = new JSONObject();
					outputObject.put(ParserConstants.COMPANY, companyName);
					outputObject.put(ParserConstants.POSITION, position);
					outputObject.put(ParserConstants.SKILL, skill);
					outputJsonArray.add(outputObject);
				}
			}
			
			System.out.println("Done! And the size of final good LinkedIn profiles is: " + 
					outputJsonArray.size());
			String companyPositionSkillStr = ParserUtil.getSelfDefinedJSONString(outputJsonArray);
			FileWriter outputFileWriter = new FileWriter(outputFilePath);
			outputFileWriter.write(companyPositionSkillStr);
			outputFileWriter.flush();
			outputFileWriter.close();
			System.out.println("Done!");
		} catch (FileNotFoundException e) {
			e.printStackTrace();
		} catch (IOException e) {
			e.printStackTrace();
		} catch (ParseException e) {
			e.printStackTrace();
		} catch (Exception e) {
			e.printStackTrace();
		}
	}
}
