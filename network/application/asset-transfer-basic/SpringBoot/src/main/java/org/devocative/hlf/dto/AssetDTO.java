package org.devocative.hlf.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Getter;
import lombok.Setter;
import lombok.ToString;

@Getter
@Setter
@ToString
public class AssetDTO {
	@JsonProperty("ID")
	private String id;
	private String color;
	private Integer size;
	private String owner;
	private Integer appraisedValue;

	@Getter
	@Setter
	@ToString
	public static class ListItem {
		@JsonProperty("Key")
		private String key;
		@JsonProperty("Record")
		private AssetDTO record;
	}
}
