package org.devocative.hlf.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Getter;
import lombok.Setter;
import lombok.ToString;

@Getter
@Setter
@ToString
public class AssetDTO {
	@JsonProperty("assetID")
	private String id;
	private String color;
	private Integer size;
	private String owner;
	private Integer appraisedValue;
}
